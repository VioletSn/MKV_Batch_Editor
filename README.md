# MKV Batch Editor

This Powershell script utilises MKVToolNix to batch edit .MKV files.
I like to have all my mkv files organised in the same way, but i find it difficult to edit them in other batch programs which feel restricted as they require you to already know what tracks are what in your files and assume that they are all the same.
As well as this, the scripts main feature is language swapping currently between two different languages. This changes the default audio and subtitle track on the file so it doesn't need to be changed manually everytime you start the video.
Anyway if you happen to use this script i hope you like it and any feedback to make it better or more efficient would be welcome ❤️

## Functions

- The script works by generating and then reading off JSON files created for each MKV video.
- After one of the functions below are selected the MKV videos are checked if they have the same number of tracks.

**Note:** Many of these functions rely on knowing the ID of the track you want to edit, function 4 will give you this information if you do not already know.

### 1. Exit

Exits the script and removes JSON files automatically if they were previously generated, otherwise just close the window and remove the .temp folder.

### 2. Reordering Tracks

Used to reorder tracks such as subtitle or audio.
Simply enter the new track order when prompted (in terms of Track ID).
- This will create a new folder and place the reordered videos into there
**Note:** This function will not overwrite the original files

**Example:** if you want to swap track 3 and 4, type in: 0,1,2,4,3

### 3. Language Switcher

**Note:** For this function to work, the track properties have to be equal across all files.

Swaps the default language by inverting the default property of audio and subtitle tracks.
- An additional feature of this is if there are more then 2 subtitle tracks the user is prompted again as to which they want enabled. (should be working)

### 4. Track Table

Creates a table of all the tracks within all the files, showing each tracks Name, ID, Language, Type, and Default status.
- This can be used after Functions 3, 5, and 7 without having to reload the script.

### 5. Remove Tags

Removes all tags (i think? i only used this once)

### 6. Remove Tracks

Just input the track ID of the track(s) to remove
- This will create a new folder and place the videos with removed tracks into there
**Note:** This function will not overwrite the original files

### 7. Rename Track

This function renames a single track across all files
- The user first has to identify which track to rename in the format: _type_+_local track number_
  - v= video, a= audio, s= subtitle
  - local track number is relative to the amount of tracks of a certain type, e.g. if you have 2 audio tracks and want to edit the second you would input: v2

## Useage

**Requires:**
- Powershell 7
- MKVToolNix

Simply download the .psy file and place it in the folder along with the MKV files you want to edit (script targets .mkv extension and will ignore other files in the same folder) and then double click to run it.
If its working properly it should display the files it can see when it opens.
If there are files moved in or out of the folder the script needs restart.

