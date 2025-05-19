import boto3, json, os, datetime, requests, base64

def lambda_handler(event, context):
    ssm = boto3.client('ssm')
    github_token = os.environ['GITHUB_TOKEN']
    github_repo = os.environ['GITHUB_REPO']
    region = os.environ['AWS_REGION']

    results = []
    with open("/tmp/instance.txt", "r") as f:
        instance_ids = [line.strip() for line in f if line.strip()]

    for instance_id in instance_ids:
        print(f"Running patch on {instance_id}")
        cmd = ssm.send_command(
            InstanceIds=[instance_id],
            DocumentName="AWS-RunShellScript",
            Parameters={
                "commands": [
                    "sudo bash /usr/bin/patchscript/instance_patches.txt > /tmp/result.txt 2>&1"
                ]
            }
        )
        cmd_id = cmd['Command']['CommandId']
        ssm.get_waiter('command_executed').wait(CommandId=cmd_id, InstanceId=instance_id)

        output = ssm.get_command_invocation(CommandId=cmd_id, InstanceId=instance_id)
        results.append({
            "instance_id": instance_id,
            "status": output['Status'],
            "output": output.get("StandardOutputContent", "")
        })

    push_patch_results_to_github(github_repo, github_token, results)
    return {"status": "patches_applied", "details": results}


def push_patch_results_to_github(repo, token, results):
    timestamp = datetime.datetime.utcnow().strftime("%Y%m%d%H%M%S")
    branch = f"patch-results-{timestamp}"
    file_path = "patch_status.json"
    commit_msg = f"Patch results from {timestamp}"
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json"
    }

    r = requests.get(f"https://api.github.com/repos/{repo}/git/ref/heads/main", headers=headers)
    main_sha = r.json()["object"]["sha"]

    requests.post(f"https://api.github.com/repos/{repo}/git/refs", headers=headers, json={
        "ref": f"refs/heads/{branch}",
        "sha": main_sha
    })

    blob_content = json.dumps(results, indent=2)
    blob_res = requests.post(f"https://api.github.com/repos/{repo}/git/blobs", headers=headers, json={
        "content": blob_content,
        "encoding": "utf-8"
    })
    blob_sha = blob_res.json()["sha"]

    tree_res = requests.post(f"https://api.github.com/repos/{repo}/git/trees", headers=headers, json={
        "base_tree": main_sha,
        "tree": [{
            "path": file_path,
            "mode": "100644",
            "type": "blob",
            "sha": blob_sha
        }]
    })
    tree_sha = tree_res.json()["sha"]

    commit_res = requests.post(f"https://api.github.com/repos/{repo}/git/commits", headers=headers, json={
        "message": commit_msg,
        "tree": tree_sha,
        "parents": [main_sha]
    })
    commit_sha = commit_res.json()["sha"]

    requests.patch(f"https://api.github.com/repos/{repo}/git/refs/heads/{branch}", headers=headers, json={
        "sha": commit_sha
    })

    pr = requests.post(f"https://api.github.com/repos/{repo}/pulls", headers=headers, json={
        "title": f"[Auto] Patch Install Results - {timestamp}",
        "head": branch,
        "base": "main",
        "body": "Patch installation results from Lambda"
    })

    print("Pull Request URL:", pr.json().get("html_url"))
