#This script will close all github repostirories for a specified user account
#Example:
#GithubBackup.py -s C:\users\Dave\github_repos -u djust270
import requests
import os
import pathlib
import argparse
import platform
from datetime import datetime
import shutil
from time import sleep
# add script arguments
parser = argparse.ArgumentParser()
parser.add_argument("-s", dest="save_location" , type=str, help="Location to save repositories")
parser.add_argument("-u", dest= "github_user" , type=str, help="Github Username to backup")
parser.add_argument("-f", action='store_true', dest="force", help="Force operation if target directory is not empty All contents of targer dir will be removed!")
parser.add_argument("-a", action='store_true', dest='mkarchive', help="Create a sigle archive of all cloned repositories")
args = vars(parser.parse_args())
# List and backup all github repositories
user = args["github_user"]
save_location = args["save_location"]
force = args["force"]
mkarchive = args["mkarchive"]
operating_system = platform.system()
target_folder = pathlib.Path(f"{save_location}/{user}")
# if target folder already exists and force flag not set, raise exception
if user in (os.listdir(pathlib.Path(save_location))) and force !=True:
    raise Exception('Target directory is not empty. Use the -f flag to force and remove contents of directoy')
# if target folder exists and force flag set, remove target folder
if user in (os.listdir(pathlib.Path(save_location))) and force ==True:
    print("Directory is not empty, removing contents")
    try :
        shutil.rmtree(pathlib.Path(target_folder))
    except PermissionError :
        if operating_system == 'Windows':
            os.system(f"powershell.exe -command \"remove-item {target_folder} -recurse -force\"")         
        elif operating_system == 'Linux' or operating_system == 'Darwin':
            os.system(f"rm -r -f {target_folder}")
# create folder with github username in save_location
os.mkdir(pathlib.Path(f"{target_folder}"))
os.chdir(pathlib.Path(f"{target_folder}"))
base_url = (f"https://api.github.com/users/{user}/repos")
get = requests.get(base_url)
json_response = get.json()
for a in json_response : 
    os.system(f"git clone {a['html_url']}")
if mkarchive == True:
    now = datetime.now()
    archive_name = f"{user}_{now.month}-{now.day}-{now.year}"
    shutil.make_archive(archive_name, 'zip', target_folder)
    shutil.move(pathlib.Path(f"{target_folder}/{archive_name}.zip"), save_location)
    
