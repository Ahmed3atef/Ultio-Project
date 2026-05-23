# Ultio Project

### Pre-requisites
this docker use below 

- bench image tag `v5.27.0`
- frappe `version-15` with all github tags for this branch
- mariadb image tag `10.6`
- redis image tag `alpine`


## How to Use

* don't forget to make ssh key and insert it to gitlab settings for your account
* firs clone this repo on your host machine 
* open vscode in the repo path `code .`
* make sure you have [VSCode Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
* Launch the command, from Command Palette (Ctrl + Shift + P) `Dev Containers: Reopen in Container`
* inside the container run `./installer.sh`