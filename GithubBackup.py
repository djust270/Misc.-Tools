#This script will close all github repostirories for a specified user account
#Example:
#GithubBackup.py -s C:\users\Dave\github_repos -u djust270
from operator import contains
import requests
import os
import pathlib
import argparse
import platform
# add script arguments
parser = argparse.ArgumentParser()
parser.add_argument("-s", dest="save_location" , type=str, help="Location to save repositories")
parser.add_argument("-u", dest= "github_user" , type=str, help="Github Username to backup")
parser.add_argument("-f", action='store_true', dest="force", help="Force operation if target directory is not empty All contents of targer dir will be removed!")
args = vars(parser.parse_args())
# List and backup all github repositories
user = args["github_user"]
save_location = args["save_location"]
force = args["force"]
os = platform.system()
os.chdir(pathlib.Path(save_location))
if len(os.listdir(pathlib.Path(save_location))) != 0 and force !=True:
    raise Exception('Target directory is not empty. Use the -f flag to force and remove contents of directoy')
if len(os.listdir(pathlib.Path(save_location))) != 0 and force ==True:
    print("Directory is not empty, removing contents")
    import shutil
    try :
        shutil.rmtree(pathlib.Path(save_location))
        os.mkdir(pathlib.Path(save_location))
    except PermissionError :
        if os == 'Windows':
            os.system(f"powershell.exe -command \"gci {save_location} | remove-item -recurse -force\"")        
        elif os == 'Linux' or os == 'Darwin':
            os.system(f"rm -r -f {save_location}")
base_url = (f"https://api.github.com/users/{user}/repos")
get = requests.get(base_url)
json_response = get.json()
for a in json_response : 
    os.system(f"git clone {a['html_url']}")
