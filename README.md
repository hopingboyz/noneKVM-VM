docker build -t ubuntu-cloudinit .


docker run -d -p 6080:6080 -p 2222:2222 -v vmdata:/data --name ubuntu-vm ubuntu-cloudinit
