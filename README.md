# FreeFileSync PowerShell Function
 A PS wrapper for the open source file sync software FreeFileSync that allows a user to perform sync actions from PowerShell.
 
# Setup
 
 Download FreeFileSyncPSFunction.ps1.
 
 Install FreeFileSync from https://freefilesync.org .

# How to Load Function
 Open a powershell and navigate to the directory containing the ps1 file

![image](https://user-images.githubusercontent.com/71462840/137845227-2b5a05d1-e36d-4b2e-ba05-95c63cc51925.png)

Load the function (by dot sourcing the file to keep the contained function in your session's memory).

![image](https://user-images.githubusercontent.com/71462840/137844870-c96af5ce-461c-4894-8b65-22fc9b9a9572.png)

You can now use the function from any path in this PowerShell session.

![image](https://user-images.githubusercontent.com/71462840/137844890-8d05bb73-ab9b-4fd3-a98f-c669b0d7619c.png)

Note that the function will be unloaded once you close the PowerShell window, and will need to be reloaded next time you open a new session.

**Tip:** Use the man command to see it's manual page.  You can use the `-Examples` or even the `-Full` switch to see more command details

![image](https://user-images.githubusercontent.com/71462840/137845366-ad8bda4d-537d-4fa3-ae1a-8e1d120d3547.png)

