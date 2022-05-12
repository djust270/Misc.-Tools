#This script will close all github repostirories for a specified user account
#Example:
#GithubBackup.py -s C:\users\Dave\github_repos -u djust270
import requests
import json
import os
import pathlib
import argparse
# add script arguments
parser = argparse.ArgumentParser()
parser.add_argument("-s", dest="save_location" , type=str, help="Location to save repositories")
parser.add_argument("-u", dest= "github_user" , type=str, help="Github Username to backup")
args = vars(parser.parse_args())
# List and backup all github repositories
user = args["github_user"]
save_location = args["save_location"]
os.chdir(pathlib.Path(save_location))
if len(os.listdir(pathlib.Path(save_location))) != 0:
    print("Directory is not empty, removing contents")
    import shutil
    try :
        shutil.rmtree(pathlib.Path(save_location))
        os.mkdir(pathlib.Path(save_location))
    except PermissionError :
        os.system(f"powershell.exe -command \"gci {save_location} | remove-item -recurse -force\"")        
base_url = (f"https://api.github.com/users/{user}/repos")
get = requests.get(base_url)
json_response = get.json()
for a in json_response : 
    os.system(f"git clone {a['html_url']}")
