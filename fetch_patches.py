import os
import requests

# Define repository and GitHub details
GITHUB_REPO = "username/repository"
GITHUB_TOKEN = "your_github_token"
PATCHES_DIR = "patches"  # Directory in the GitHub repository containing patches
LOCAL_PATCH_DIR = "local_patches"  # Local directory to store fetched patches

# Set up headers for GitHub API requests
headers = {
    'Authorization': f'token {GITHUB_TOKEN}',
    'Accept': 'application/vnd.github.v3.raw'
}

def fetch_patches_from_github():
    url = f"https://api.github.com/repos/{GITHUB_REPO}/contents/{PATCHES_DIR}"
    response = requests.get(url, headers=headers)
    response.raise_for_status()
    patches = response.json()
    
    if not os.path.exists(LOCAL_PATCH_DIR):
        os.makedirs(LOCAL_PATCH_DIR)
    
    for patch in patches:
        patch_url = patch['download_url']
        patch_response = requests.get(patch_url, headers=headers)
        patch_response.raise_for_status()
        
        patch_file_path = os.path.join(LOCAL_PATCH_DIR, patch['name'])
        with open(patch_file_path, 'wb') as patch_file:
            patch_file.write(patch_response.content)
        print(f"Fetched patch: {patch['name']}")

def main():
    fetch_patches_from_github()
    print("Patches have been successfully fetched from GitHub.")

if __name__ == "__main__":
    main()
