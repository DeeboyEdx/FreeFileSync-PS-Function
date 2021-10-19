# FreeFileSync PowerShell Function
 A PowerShell wrapper for the open source file sync software FreeFileSync which brings the ability to synchronize files between two or more paths to PowerShell.  This is **only for the Windows platform**.  I made this because I wanted to be able to...
 - Run multiple sync jobs in series[^3]
 - Execute jobs programmatically from PowerShell
 - and potentially run it minimized but still retain the ability to see a results summary easily.[^4]
 
# Setup
 
 Download FreeFileSyncPSFunction.ps1 or copy its code to your own ps1 file[^1].
 
 Get FreeFileSync from [their website](https://freefilesync.org) and install it to its default path, `C:\Program Files\FreeFileSync`.

# How to Load the Function
Open a PowerShell session and navigate to the directory containing the ps1 file.

![image of changing directory to scripts folder in PS](https://user-images.githubusercontent.com/71462840/137852010-6f297c72-947c-4f50-874c-c653f59324d3.png)


Load the function (by dot sourcing the file to keep the contained function in your session's memory).

![image of dot sourcing the ps1 file in PS](https://user-images.githubusercontent.com/71462840/137844870-c96af5ce-461c-4894-8b65-22fc9b9a9572.png)

You can now use the function from any path in this PowerShell session.

![image demonstrating the function name in PS](https://user-images.githubusercontent.com/71462840/137844890-8d05bb73-ab9b-4fd3-a98f-c669b0d7619c.png)

Note that the function will be unloaded once you close the PowerShell window, and will need to be reloaded next time you open a new session.

**Tip:** Use the `man` command to see its manual page.  You can use the `-Examples` or even the `-Full` switch to see more details

![image of function's manual page in PS](https://user-images.githubusercontent.com/71462840/137845366-ad8bda4d-537d-4fa3-ae1a-8e1d120d3547.png)


# Example (adhoc) use case
Let's say you want to sync what's in your default Desktop folder ***TO*** your OneDrive Desktop folder.

![image in PS of user's Desktop and OneDrive Desktop paths](https://user-images.githubusercontent.com/71462840/137846281-ef1de430-4ee3-48df-b1b2-8a4469916e59.png)

Sync the folders like so...

<!-- A code line might be better since a user can copy/paste it so I'll hide this image for now.
![image in PS demonstrating how to use the function to sync that paths](https://user-images.githubusercontent.com/71462840/137846345-67e7b691-dd14-4550-b075-cb3c8ad2575e.png) -->
`Free-File-Sync -Source "$env:USERPROFILE\Desktop" -Destination "$env:OneDrive\Desktop"`


# Sync Varieties

An option when using the `-Source`/`-Destination` parameter pair, there are three `-SyncType` arguments available.
- **Update** - *This function's default sync behavior.*  It will only copy over new files and update files which are newer in your source path.  It will not remove files or replace files which are newer in your destination path.  In case of conflicts, it will open the GUI.
- **Mirror** - Forces destination to match source.  In other words, it replaces existing files regardless of whether they are newer or not and erases those from the destination path that do not exist in the source path.
- **TwoWay** - Similarly to Mirror in that both sides match at the end, but instead of Source files having priority, the priority is decided for each file based on its last update time and size.  In case of conflicts, it will open the GUI.  I recommend viewing their [TwoWay tutorial video on youtube](https://www.youtube.com/watch?v=2hoShXeEDdQ&t=184s) and/or run tests first to familiarize yourself with this method.


# Example use case
Let's say you have several sync job files already created[^2] that sync your pictures/videos to your redundant backup locations...
![image depicting multiple FFS sync batch files](https://user-images.githubusercontent.com/71462840/137849815-3bbd7c95-d06c-4edd-b965-bd9800d2c453.png)
and want to execute multiple jobs with one command.

Use the function like so...

`Free-File-Sync -JobsPath "$env:OneDrive\Desktop\Sync Configs\" -Filter 'Sync G-*'`

**Note:** Instead of using a wildcard (`*`), you can also specify multiple job files by listing them separated with commas.
![image depicting multiple explicit FFS job files without wildcard * use](https://user-images.githubusercontent.com/71462840/137850412-55a5be5f-4ed4-41d9-85c7-edb4a680f29a.png)


A final footnote[^5].


[^1]:  By default PowerShell's Execution Policy does not permit running foreign code.  You may want to remove the restriction with `Set-ExecutionPolicy -ExecutionPolicy Bypass` in a PS session as Admin but if you're uncomfortable making that policy change on your machine, copy, pasting and saving the script as your own ps1 file is a work-around.
[^2]: Job files are created using the FFS GUI.
[^3]: It is possible to execute multiple batch jobs at once.  In theory, subsequent jobs will wait for the first one to finish before starting.  But in my experience, in this scenario, one of them often chokes and fails to start after the last one finished, thus blocking the remaining sync jobs.
[^4]: I'm aware FFS does present a final success message and have logs but I don't find the GUI as reassuring as a simple one-liner in a console window.
[^5]: In case of any warnings or errors, the function will automatically open the sync job's logs for your review; given that you haven't changed the default log location.
