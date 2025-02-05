[System.Console]::WindowWidth = 200
[System.Console]::WindowHeight = 40

$debug = $args[0] # Check if the script is in debug mode from .bat file
Write-Host "Debug = $debug" -ForegroundColor DarkGray

# Initialize variables
[string]$mkvmerge = "C:\Program Files\MKVToolNix\mkvmerge.exe"
[string]$mkvpropedit = "C:\Program Files\MKVToolNix\mkvpropedit.exe"
[string]$jsonFilesDirectory = "temp\"
[int]$fileCount = 0
[int]$exit = 0
[int]$currentTrackCountMis = 0
[int]$misMatch = 0
[int]$operation = 0

# Returns true if first input (value) is not a multiple of the second (divisor)
function NotMultipleOf ($value, $divisor) {
	$remainder = $value
	while ($remainder -ge $divisor) {
		$remainder -= $divisor
	}
	
	if ($remainder -eq 0) {
		return $false
	} else {
		return $true
	}
}

# Display files for change
Write-Host "===================== Files For Change =====================" -ForegroundColor blue
Get-ChildItem -Filter "*.mkv" | ForEach-Object {
	Write-Host $_.BaseName
	$fileCount++
}

if ($fileCount -eq 0) {
	Write-Host "`nNo MKV files found`n" -ForegroundColor Red
	pause
	Exit
} else {
	Write-Host "`nFile Count: $fileCount"
}

# Main Code
while ($exit -ne 1) {
	# Get user confirmation
	Write-Host "======================== Operation =========================" -ForegroundColor blue
	$operation = Read-Host -Prompt "Select Operation [Exit(1), Reorder Tracks(2), Language Switcher(3), Track Table(4), Remove Tags(5), Remove Tracks(6), Rename Track(7), Set Title to Filename(8)]"

	if ($operation -eq "exit" -or $operation -eq "1") {
		$exit = 1
	} elseif (($operation -lt 2) -or ($operation -gt 8)) {
		Write-Host "Enter a valid integer input." -ForegroundColor DarkRed
	} else {
		# Create temp folder if it doesn't exist already
		Write-Host "`nCreating temp Folder" -NoNewLine
		if (!(Test-Path "temp")) {
			[void] (New-Item -ItemType Directory -Name "temp")
			$temp = Get-Item ".\temp"
			$temp.Attributes = $temp.Attributes -bor "Hidden"

			Write-Host " >Done" -ForegroundColor Green
		} else {
			Write-Host " >Already Exists" -ForegroundColor Yellow
		}
		
		$jsonCount = 0
		$trackCounts = [ordered] @{} # Initialize empty ordered hashtable
		$mkvFiles = Get-ChildItem -Filter "*.mkv"

		# Create JSONs for each mkv file
		if ($debug -eq $false) { Write-Host "Generating JSON Files " -NoNewLine }
		if ($debug -eq $true) { Write-Host "Generating JSON Files:" }
		Get-ChildItem -Filter "*.mkv" | ForEach-Object {
			& $mkvmerge --identification-format json --identify $_.FullName | Out-File "temp\$($_.BaseName.Replace('[','').Replace(']','')).json"
			if ($debug -eq $true) {
				Write-Host "Done > $($_.Name)" -ForegroundColor Magenta
			}
			$jsonCount++
			$jsonFile = "temp\$($_.BaseName.Replace('[','').Replace(']','')).json"
			$jsonContent = Get-Content $jsonFile
			$jsonData = $jsonContent | ConvertFrom-Json
			$tracks = $jsonData.tracks
			$currentTrackCount = $tracks.Count
			$trackCounts[$_.Name] = $currentTrackCount
		}
		if ($debug -eq $false) { Write-Host ">Done " -ForegroundColor Green }
		
		# Check if Track Counts are Equal Across mkv Files
		if ($jsonCount -eq $fileCount) {
			if ($debug -eq $false) { Write-Host "Checking Track Equality" -NoNewLine }
			if ($debug -eq $true) { Write-Host "Checking Track Equality:" }
			
			$countTable = @{} # Hashtable to store the count of each value in trackCounts hashtable
			# Count occurrences of each value
			foreach ($value in $trackCounts.Values) {
				if ($countTable.ContainsKey($value)) {
					$countTable[$value]++
				} else {
					$countTable[$value] = 1
				}
			}

			# Find the most common track count among mkv files
			$modeTrackCount = ($countTable.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
			if ($debug -eq $true) {
				Write-Host "Mode Tracks " -NoNewline
				Write-Host ">$modeTrackCount" -ForegroundColor Yellow
			}
			
			# Identify keys with mismatching track counts
			$mismatchedKeys = @()
			foreach ($key in $trackCounts.Keys) {
				if ($trackCounts[$key] -ne $modeTrackCount) {
				$mismatchedKeys += $key  # Add the current key to the array
				}
			}
			
			if ($mismatchedKeys.Count -gt 0) {
				$misMatch = 1
				$currentTrackCountMis = $modeTrackCount
				if ($debug -eq $false) {
					Write-Host " >Mismatch Found in the Following Files:" -ForegroundColor DarkRed
				} else {
					Write-Host "Mismatch Found in the Following Files:" -ForegroundColor DarkRed
				}
				$mismatchedKeys | ForEach-Object {
					Write-Host " - ("$trackCounts[$_] Tracks") $_" -ForegroundColor Red
					if ($trackCounts[$_] -gt $currentTrackCountMis) {
						$currentTrackCountMis = $trackCounts[$_]
						if ($debug -eq $true) { Write-Host "Highest Count: $currentTrackCountMis" -ForegroundColor Magenta }
					}
				}
				Write-Host ""
			} else {
				$misMatch = 0
				if ($debug -eq $false) {
					Write-Host " >Matching`n" -ForegroundColor Green
				} else {
					Write-Host "All files have matching track counts" -ForegroundColor Green
				}
			}
		}
		
		if ($operation -eq "Reorder Tracks" -or $operation -eq "2") {
			Write-Host "====================== Reorder Tracks ======================" -ForegroundColor blue
			
			$2newTrackOrder = Read-Host -Prompt "Enter new track order (e.g., 0,1,2,4,3)"
			# Convert user input to MKVmerge format
			$2newTrackOrder = "0:" + $2newTrackOrder -Replace ",\s*", ",0:"

			if ($debug -eq $true) {
				Write-Host $2newTrackOrder
			}

			# Ensure "MODIFIED" folder exists
			Write-Host "`nCreating MODIFIED Folder" -NoNewLine
			if (!(Test-Path -Path "MODIFIED")) {
				[void] (New-Item -ItemType Directory -Name "MODIFIED")

				Write-Host " >Done" -ForegroundColor green
			} else {
				Write-Host " >Already Exists" -ForegroundColor Yellow
			}

			# Loop through each MKV file
			if ($debug -eq $true) {
				foreach ($mkvFile in $mkvFiles) {
					Write-Host "`nProcessing " -NoNewline
					Write-Host (">" + $mkvFile.BaseName) -ForegroundColor Yellow

					# Create a new file name for the output file
					$outputFileName = "$($mkvFile.BaseName)_reordered.mkv"
					
					# Construct the full output file path
					$outputFile = Join-Path -Path "MODIFIED" -ChildPath $outputFileName
					
					# Run MKVmerge to reorder the tracks
					& $mkvmerge -o $outputFile "$mkvFile" --track-order $2newTrackOrder
					
					Write-Host "Done." -ForegroundColor green
				}
				Write-Host "All files processed successfully!" -ForegroundColor green
			} else {
				$2processed = 0
				Write-Host "Processing " -NoNewline
				foreach ($mkvFile in $mkvFiles) {
					Write-Progress -Activity "Reordering" -Status $mkvFile.BaseName -PercentComplete (($2processed / $fileCount) * 100)
					$2processed++

					# Create a new file name for the output file
					$outputFileName = "$($mkvFile.BaseName)_reordered.mkv"
					
					# Construct the full output file path
					$outputFile = Join-Path -Path "MODIFIED" -ChildPath $outputFileName
					
					# Run MKVmerge to reorder the tracks
					& $mkvmerge -o $outputFile "$mkvFile" --track-order $2newTrackOrder > $null					
				}
				Write-Host ">Done" -ForegroundColor green
				Write-Progress -Completed -Activity "Reordering" -Status "Complete" -PercentComplete 100
			}
			
		} elseif ($operation -eq "Language Switcher" -or $operation -eq "3") {
			Write-Host "===================== Language Switcher =====================" -ForegroundColor blue
			
			# Initiate array structures and variables
			$array = @() # for all track information
			$multi = @() # for track information on duplicate types

			$highestTrackNum = 0
			$currentTypeCount = 0
			$previousType = $null

			$currentDefaultCount = 0
			$previousDefault = $null

			$counter = 0

			while ($counter -le $currentTrackCount -1) {
				# Iterate through Json files to extract track information
				Get-ChildItem -Path $jsonFilesDirectory -Filter "*.json" -Recurse | ForEach-Object {
					$jsonData = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json
					
					$trackInfo = [PSCustomObject]@{
						FileOrigin = $_.BaseName
						LocalTypeNum = 0  # Counts number of tracks of similar type
						Name = $jsonData.tracks[$counter].properties.track_name
						ID = $jsonData.tracks[$counter].id
						Language = $jsonData.tracks[$counter].properties.language
						Type = $jsonData.tracks[$counter].type
						LocalDefaultNum = 0 # Counts number of tracks of similar default value
						Default = $jsonData.tracks[$counter].properties.default_track
					}
					
					# Array object for tracks of duplicate type
					$multiTracks = [PSCustomObject]@{
						LocalTypeNum = 0
						Name = $jsonData.tracks[$counter].properties.track_name
						ID = $jsonData.tracks[$counter].id
						Language = $jsonData.tracks[$counter].properties.language
						Type = $jsonData.tracks[$counter].type
						LocalDefaultNum = 0
					}
					
					# Adjusting Local Type Number (LTN) based on Track Type
					if ($trackInfo.Type -eq $previousType) { # Same type as previous track type
						$currentTypeCount++
						
						if ($fileCount -eq 1) { # Single file scenario
							$trackInfo.LocalTypeNum = $currentTypeCount
							$multiTracks.LocalTypeNum = $currentTypeCount
						} else { # Multiple file scenario
							$trackInfo.LocalTypeNum = [int][Math]::Floor(($currentTypeCount - 1) / $fileCount) + 1
							$multiTracks.LocalTypeNum = [int][Math]::Floor(($currentTypeCount - 1) / $fileCount) + 1
						}
						
					} else { # New track type, different from previous
						$currentTypeCount = 1
						$trackInfo.LocalTypeNum = 1
						$multiTracks.LocalTypeNum = 1
						$previousType = $trackInfo.Type
					}
					
					# Adjusting Local Default Number (LDN) based on Default status
					if ($trackInfo.Default -eq $previousDefault) { # Same default status as previous track
						$currentDefaultCount++
								
						if ($fileCount -eq 1) { # Single file scenario
							$trackInfo.LocalDefaultNum = $currentDefaultCount
							$multiTracks.LocalDefaultNum = $currentDefaultCount
						} else { # Multiple file scenario
							$trackInfo.LocalDefaultNum = [int][Math]::Floor(($currentDefaultCount - 1) / $fileCount) + 1
							$multiTracks.LocalDefaultNum = [int][Math]::Floor(($currentDefaultCount - 1) / $fileCount) + 1
						}
								
					} else { # New default status, different from previous
						$currentDefaultCount = 1
						$trackInfo.LocalDefaultNum = 1
						$multiTracks.LocalDefaultNum = 1
						$previousDefault = $trackInfo.Default
					}

					if (!$trackInfo.Default) {
						if ($trackInfo.Type -eq "Audio") {
							$multi += $multiTracks
						} elseif ($trackInfo.Type -eq "Subtitles") {
							$multi += $multiTracks
						}
					}
					
					# Stores a variable for the highest local type number
					if ($trackInfo.LocalTypeNum -gt $highestTrackNum) {
						$highestTrackNum = $trackInfo.LocalTypeNum
					}
					
					# True if there are 3 or more tracks of the same type within a given file
					if ($trackInfo.LocalTypeNum -ge 3) {
						$extraTrack = $true
					} else {
						$extraTrack = $false
					}
					
					$array += $trackInfo
				}
				$counter++
			}

			# Clears multi (multiple track array) if there are no extra tracks
			if ($highestTrackNum -le 2 -or $extraTrack -eq $false -or $multi.Count -eq $currentTrackCount -1) {
				Write-Host "Clearing multi"
				$multi = @()
			}

			Write-Host "number of elements in multi:"$multi.Count
			Write-Host "track count:"$currentTrackCount

			$multi | Format-Table -Autosize -Wrap
			if ($debug -eq $true) {
				$array | Format-Table -Autosize -Wrap
			}

			# Function to check if tracks have the same values across files
			function Confirm-TrackEquality {
				param(
					[Parameter(Mandatory = $true)]
					[array]$array
				)
				
				foreach ($Track in $array) {
					if ($Track.Count -eq 0) {
						Write-Host "Empty track encountered." -ForegroundColor DarkRed
						continue
					}
					
					# Checks the current track with the track before it, ignoring when track types switch naturally
					for ([int]$j = 1; $j -lt $array.Count-1; $j++) {
						$refName = $array[$j-1].Name
						$refID = $array[$j-1].ID
						$refLanguage = $array[$j-1].Language
						$refType =  $array[$j-1].Type
						$refDefault = $array[$j-1].Default
						#DEBUG Write-Host "Reference Property: $refName, $refID, $refLanguage, $refType, $refDefault"
						#DEBUG Write-Host "Current Property  :" $array[$j].Name"," $array[$j].ID"," $array[$j].Language"," $array[$j].Type"," $array[$j].Default
						
						if ((($array[$j].Language -ne $refLanguage) -or ($array[$j].Type -ne $refType) -or ($array[$j].ID -ne $refID) -or ($array[$j].Name -ne $refName) -or ($array[$j].Default -ne $refDefault)) -And (NotMultipleOf $j $fileCount)) {
							if ($debug -eq $true) { Write-Host "FALSE" -ForegroundColor DarkRed }
							return $false
						}
					}
					#DEBUG Write-Host "Track CLEARED" -ForegroundColor green
				}
				if ($debug -eq $true) { Write-Host "TRUE" -ForegroundColor green }
				return $true
			}

			# Initiate hashtables
			$audioOptions = @{}
			$subtitleOptions = @{}
			$selectedAudio = @{}
			$toRemove = @{}

			# Check track equality
			if (Confirm-TrackEquality -array $array) {
				Write-Host "Adjacent track properties are EQUAL" -ForegroundColor green
				
				$activeLanguage = $null
				
				# Identify the current and non-current language
				foreach ($trackInfo in $array) {
					if ($trackInfo.Type -eq 'audio' -and $trackInfo.Default -eq $true) {
						$activeLanguage = $trackInfo.Language
					} elseif ($trackInfo.Type -eq 'audio' -and $trackInfo.Default -eq $false) {
						$newLanguage = $trackInfo.Language
					}
				}
				
				if ($null -ne $activeLanguage) {
					Write-Host "Active track language: " -NoNewline
					Write-Host $activeLanguage -ForegroundColor Yellow
					
					$confirm = Read-Host "Swap Language? [Y/N]"
					if ($confirm -eq "Y" -or $confirm -eq "y") {

						# Create functions
						function 3Reference () { # Function for generating reference data
							if ($debug -eq $true) {
								Write-Host "Reference " -NoNewline
								Write-Host ">$mkvType$mkvNum" -ForegroundColor yellow
							}
						}

						function 3DefaultEdit { # Function for switching default track
							param(
								[int] $defaultType,
								[string] $switchMesg
							)
						
							if ($debug -eq $true) {
								& $mkvpropedit $currentFile --edit track:$mkvType$mkvNum --set flag-default=$defaultType
								Write-Host "set" $trackInfo.Name "$switchMesg" -ForegroundColor Magenta
							} else {
								& $mkvpropedit $currentFile --edit track:$mkvType$mkvNum --set flag-default=$defaultType > $null
							}
						}

						function 3SwitchLanguage { # Main function for utilising mkvPropEdit
							param(
								[string] $mkvType,
								[string] $toDefault
							)
						
							$mkvNum = $trackInfo.LocalTypeNum
						
							if ($extraTrack -eq $true) {
								
								# Identify track to set to default
								Write-Host "Selected:"$toDefault
								3Reference
								
								# Check for three tracks with specific default values
								if ($trackInfo.Default -eq $true) {
									3DefaultEdit -defaultType 0 -switchMesg "FALSE (all)" # set all tracks default false
						
									# Modify default settings based on user selection
									if ($trackInfo.Name -eq $toDefault) {
										3DefaultEdit -defaultType 1 -switchMesg "TRUE (selected)" # set selected tracks default true
									} else {
										3DefaultEdit -defaultType 0 -switchMesg "FALSE" # set unselected tracks default false
									}
								} elseif ($trackInfo.Default -eq $false) {
									3DefaultEdit -defaultType 1 -switchMesg "TRUE (all)" # set all tracks default true
						
									# Modify default settings based on user selection
									if ($trackInfo.Name -eq $toDefault) {
										3DefaultEdit -defaultType 1 -switchMesg "TRUE (selected)" # set selected tracks default true
									} else {
										3DefaultEdit -defaultType 0 -switchMesg "FLASE" # set unselected tracks default false
									}
								}
							
							# No extra tracks
							} elseif ($extraTrack -eq $false) {
								if ($trackInfo.Default -eq $true) {
									3Reference
									3DefaultEdit -defaultType 0 -switchMesg "FALSE"
						
								} elseif ($trackInfo.Default -eq $false) {
									3Reference
									3DefaultEdit -defaultType 1 -switchMesg "TRUE"
						
									if ($mkvType -eq "a") {
										if ($trackinfo.Language -eq $activeLanguage -and $multi.Count -ne 0) {
											3Reference
											3DefaultEdit -defaultType 0 -switchMesg "FALSE (reverse)"
						
										}
									} elseif ($mkvType -eq "s") {
										if ($trackinfo.Name -ne "Signs & Songs" -and $multi.Count -ne 0) {
											3Reference
											3DefaultEdit -defaultType 0 -switchMesg "FALSE (reverse)"
										}
									}
								}
							}
						}

						# places audio tracks from multi into isolated array before checking language equality
						$audioMulti = $multi | Where-Object {$_.Type -eq "Audio"}

						if ($extraTrack -eq $true) {
							if ($audioMulti[0].Language -ne $audioMulti[$fileCount].Language) {
								Write-Host "Audio tracks in multi have differing languages" -ForegroundColor DarkYellow
								$extraTrack = $false
							} else {
								Write-Host "2 or more tracks of similar type identified" -ForegroundColor DarkYellow
								
								# Define user Options for both audio and subtitles from the multi track array
								foreach ($multiTracks in $multi) {
									if ($multiTracks.Type -eq "Audio" -and $multiTracks.Language -ne $activeLanguage) {
										$audioOptions[$multiTracks.LocalDefaultNum] = $multiTracks.Name
									} elseif ($multiTracks.Type -eq "Subtitles") {
										$subtitleOptions[$multiTracks.LocalDefaultNum] = $multiTracks.Name
									} else {
										Write-Host "Track in multi not of type Audio or Subtitle or is of activelanguage" -ForegroundColor DarkRed
									}
								}
								
								# Retrieve user selected Audio track and which Audio option to discard
								if ($audioOptions.Keys.Count -ge 2) {
									Write-Host "Audio Options: "
									$audioOptions | Format-Table
									
									# Dynamically changes prompt options to match availible options
									$audioOptionsCount = $audioOptions.Count
									for ($i = 1; $i -le $audioOptionsCount; $i++) {
										$audioUserPrompt += "[" + $audioOptions[$i] + " /" + $($i) + "] "
									}

									[int]$audioConfirm = Read-Host "Select Desired Audio Default: " $audioUserPrompt
									Write-Host "Selected:"$audioOptions[$audioConfirm]
									pause
									
									foreach ($multiTracks in $multi) {
										if ($audioConfirm -eq $multiTracks.LocalDefaultNum -and $multiTracks.Type -eq "Audio") {
											Write-Host "Skip selected Audio Track [" $audioOptions[$audioConfirm] "] ID ["$multiTracks.ID"]"
											$selectedAudio = $multiTracks.Name
										} elseif ($audioConfirm -ne $multiTracks.LocalDefaultNum -and $multiTracks.Type -eq "Audio") {
											Write-Host "Remove Audio Option ["$multiTracks.LocalDefaultNum"] ID ["$multiTracks.ID"]"
											$toRemove = $multiTracks.Name
										}
									}
									$selectedAudio | format-table
									$toRemove | format-table
									
								}
								
								# Retrieve user selected Subtitle track and which Subtitle option to discard
								if ($subtitleOptions.Keys.Count -ge 2) {
									Write-Host "Subtitle Options: "
									$subtitleOptions | Format-Table
									
									# Dynamically changes prompt options to match availible options
									$subtitleOptionsCount = $subtitleOptions.Count
									for ($i = 1; $i -le $subtitleOptionsCount; $i++) {
										$subtitleUserPrompt += "[" + $subtitleOptions[$i] + " /" + $($i) + "] "
									}

									[int]$subtitleConfirm = Read-Host "Select Desired Subtitle Default: " $subtitleUserPrompt
									Write-Host "Selected:"$subtitleOptions[$subtitleConfirm]
									pause
									
									foreach ($multiTracks in $multi) {
										if ($subtitleConfirm -eq $multiTracks.LocalDefaultNum -and $multiTracks.Type -eq "Subtitles") {
											Write-Host "Skip selected Subtitle Track [" $subtitleOptions[$subtitleConfirm] "] ID ["$multiTracks.ID"]"
											$selectedSubtitle= $multiTracks.Name
										} elseif ($subtitleConfirm -ne $multiTracks.LocalDefaultNum -and $multiTracks.Type -eq "Subtitles") {
											Write-Host "Remove Subtitle Option ["$multiTracks.LocalDefaultNum"] ID ["$multiTracks.ID"]"
											$toRemove = $multiTracks.Name
										}
									}
									$selectedSubtitle | format-table
									$toRemove | format-table
								}
							}
						}

						if ($debug -eq $false) {
							Write-Host "`nSwitching Default Language " -NoNewline
							$3processed = 0
						} else {
							Write-Host ""
						}
						
						# Recurse through each MKV file and apply changes
						Get-ChildItem -Filter "*.mkv" | ForEach-Object {
							$currentFile = $_.Name

							if ($debug -eq $false) {
								Write-Progress -Activity "Switching" -Status $_.BaseName -PercentComplete (($3processed / $fileCount) * 100)
								$3processed++
							}
							
							if ($debug -eq $true) {
								Write-Host "Switching " -NoNewline
								Write-Host (">" + $_.BaseName) -ForegroundColor Yellow
							}
							
							[int]$index = 0
							foreach ($trackInfo in $array) {
								if (!(NotMultipleOf $index $fileCount)) {
									if ($trackInfo.Type -eq 'audio') {
										3SwitchLanguage -mkvType "a" -toDefault $selectedAudio
										
									} elseif ($trackInfo.Type -eq 'subtitles') {
										3SwitchLanguage -mkvType "s" -toDefault $selectedSubtitle
									}
								}
								$index++
							}
						}
						Write-Host ">Done" -ForegroundColor Green
						if ($debug -eq $false) {
							Write-Progress -Completed -Activity "Switching" -Status "Complete" -PercentComplete 100
							$3processed = 0
						}
					} else {
						$exit = 1
					}
					Write-Host "Successfully switched language from [$activeLanguage]--->[$newLanguage]" -ForegroundColor DarkGreen
				} else {
					Write-Host "No active audio track found with Default = True" -ForegroundColor DarkRed
				}
			} else {
				Write-Host "Adjacent track properties are DIFFERENT" -ForegroundColor DarkRed
			}
			
		} elseif ($operation -eq "Track Table" -or $operation -eq "4") {
			Write-Host "======================= Track Table ========================" -ForegroundColor blue
			
			# Extract track information from all JSON files
			$array = @()
			$counter = 0
			if ($misMatch -eq 1) { # If files contain varying track counts
				while ($counter -le $currentTrackCountMis -1) {
					Get-ChildItem -Path $jsonFilesDirectory -Filter "*.json" -Recurse | ForEach-Object {
						$jsonData = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json
						
						if ($jsonData.tracks.Count -gt $counter) {
							# Create track object if track exists
							$trackInfo = [PSCustomObject]@{
								FileOrigin = $_.BaseName
								Name = $jsonData.tracks[$counter].properties.track_name
								ID = $jsonData.tracks[$counter].id
								Language = $jsonData.tracks[$counter].properties.language
								Type = $jsonData.tracks[$counter].type
								Default = $jsonData.tracks[$counter].properties.default_track
							}
						} else {
							# Create "null" row if track is missing
							$trackInfo = [PSCustomObject]@{
								FileOrigin = "-null-"
								Name = ""
								ID = ""
								Language = ""
								Type = ""
								Default = ""
							}
						}
						$array += $trackInfo
					}
					$counter++
				}
			} else { # If all files contain the same number of tracks:
				while ($counter -le $currentTrackCount -1) {
					Get-ChildItem -Path $jsonFilesDirectory -Filter "*.json" -Recurse | ForEach-Object {
						$jsonData = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json
						
						# Create track object
						$trackInfo = [PSCustomObject]@{
							FileOrigin = $_.BaseName
							Name = $jsonData.tracks[$counter].properties.track_name
							ID = $jsonData.tracks[$counter].id
							Language = $jsonData.tracks[$counter].properties.language
							Type = $jsonData.tracks[$counter].type
							Default = $jsonData.tracks[$counter].properties.default_track
						}
						$array += $trackInfo
					}
					$counter++
				}
			}

			# Generate the table
			$array | Format-Table -Autosize -Wrap
			
		} elseif ($operation -eq "Remove Tags" -or $operation -eq "5") {
			Write-Host "======================= Remove Tags ========================" -ForegroundColor blue
			Write-Host "WARNING- " -NoNewLine -ForegroundColor DarkRed
			Write-Host "This Operation Removes ALL Tags from the file." -ForegroundColor Red
			$5Confirmation = Read-Host -Prompt "Continue? [Y/N]"
			Write-Host ""

			if ($5Confirmation -eq "Y" -or $5Confirmation -eq "y") {
				# Loops through all .mkv files within the current directory
				if ($debug -eq $true) {
					foreach ($mkvFile in $mkvFiles) {
						# Run MKVpropedit to remove tags
						$5peOutput = & $mkvpropedit "$mkvFile" --tags all:

						# Modify and display output
						$5peOutputLinesMod = $5peOutput.Trim().Split([Environment]::NewLine)
						foreach ($line in $5peOutputLinesMod) {
							switch ($line) {
								"The file is being analyzed." {
									Write-Host "Analyzing " -NoNewline
									Write-Host (">" + $mkvFile.BaseName) -ForegroundColor Yellow
								}
								"Done." {
									Write-Host "Done." -ForegroundColor Green
								}
								default { Write-Host $line }
							}
						}
					}
					Write-Host "All files processed successfully!" -ForegroundColor green
				} else {
					$5processed = 0
					Write-Host "Processing " -NoNewline
					foreach ($mkvFile in $mkvFiles) {
						Write-Progress -Activity "Removing Tags" -Status $mkvFile.BaseName -PercentComplete (($5processed / $fileCount) * 100)
						$5processed++

						& $mkvpropedit "$mkvFile" --tags all: > $null
					}
					Write-Host ">Done" -ForegroundColor green
					Write-Progress -Completed -Activity "Removing Tags" -Status "Complete" -PercentComplete 100
				}
			} else {
				$exit = 1
			}
			
		} elseif ($operation -eq "Remove Tracks" -or $operation -eq "6") {
			Write-Host "====================== Remove Tracks =======================" -ForegroundColor blue
			$6tracksToRemove = Read-Host -Prompt "List Tracks to Remove (e.g. 0,3,4)"
			
			# Ensure "MODIFIED" folder exists
			Write-Host "`nCreating MODIFIED Folder" -NoNewLine
			if (!(Test-Path -Path "MODIFIED")) {
				[void] (New-Item -ItemType Directory -Name "MODIFIED")
				
				Write-Host " >Done" -ForegroundColor green
			} else {
				Write-Host " >Already Exists" -ForegroundColor Yellow
			}
			
			# Loop through each MKV file
			if ($debug -eq $true) {
				foreach ($mkvFile in $mkvFiles) {
					Write-Host "`nProcessing " -NoNewline
					Write-Host (">" + $mkvFile.BaseName) -ForegroundColor Yellow
					
					# Create a new file name for the output file
					$outputFileName = "$($mkvFile.BaseName)_MODIFIED.mkv"
					
					# Construct the full output file path
					$outputFile = Join-Path -Path "MODIFIED" -ChildPath $outputFileName
					
					# Run MKVmerge to reorder the tracks and create the new file
					& $mkvmerge -o $outputFile --audio-tracks !$6tracksToRemove --video-tracks !$6tracksToRemove --subtitle-tracks !$6tracksToRemove "$mkvFile"
					
					Write-Host "Done." -ForegroundColor Green
				}
				Write-Host "All files processed successfully!" -ForegroundColor green
			} else {
				$6processed = 0
				Write-Host "Processing " -NoNewline
				foreach ($mkvFile in $mkvFiles) {
					Write-Progress -Activity "Removing Tracks" -Status $mkvFile.BaseName -PercentComplete (($6processed / $fileCount) * 100)
					$6processed++

					# Create a new file name for the output file
					$outputFileName = "$($mkvFile.BaseName)_MODIFIED.mkv"
					
					# Construct the full output file path
					$outputFile = Join-Path -Path "MODIFIED" -ChildPath $outputFileName
					
					# Run MKVmerge to reorder the tracks and create the new file
					& $mkvmerge -o $outputFile --audio-tracks !$6tracksToRemove --video-tracks !$6tracksToRemove --subtitle-tracks !$6tracksToRemove "$mkvFile" > $null
				}
				Write-Host ">Done" -ForegroundColor Green
				Write-Progress -Completed -Activity "Removing Tracks" -Status "Complete" -PercentComplete 100
			}

		} elseif ($operation -eq "Rename Track" -or $operation -eq "7") {
			Write-Host "======================= Rename Track =======================" -ForegroundColor blue
			$7renameTrack = Read-Host -Prompt "Which track do you want to rename? (e.g. v1,a2)"
			$7newName = Read-Host -Prompt "Enter the new name"
			Write-Host ""

			# Loop through each MKV file
			if ($debug -eq $true) {
				foreach ($mkvFile in $mkvFiles) {
					# Run MKVpropedit to rename the desired track
					$7peOutput = & $mkvpropedit $mkvFile --edit track:$7renameTrack --set name="$7newName"

					# Modify and display output
					$7peOutputLinesMod = $7peOutput.Trim().Split([Environment]::NewLine)
					foreach ($line in $7peOutputLinesMod) {
						switch ($line) {
							"The file is being analyzed." {
								Write-Host "Analyzing " -NoNewLine
								Write-Host (">" + $mkvFile.BaseName) -ForegroundColor Yellow
							}
							"Done." {
								Write-Host "Done." -ForegroundColor Green
							}
							default { Write-Host $line }
						}
					}
				}
				Write-Host "All files processed successfully!" -ForegroundColor green
			} else {
				$7processed = 0
				Write-Host "Processing " -NoNewLine
				foreach ($mkvFile in $mkvFiles) {
					Write-Progress -Activity "Renaming" -Status $mkvFile.BaseName -PercentComplete (($7processed / $fileCount) * 100)
					$7processed++
					
					& $mkvpropedit $mkvFile --edit track:$7renameTrack --set name="$7newName" > $null
				}
				Write-Host ">Done" -ForegroundColor green
				Write-Progress -Completed -Activity "Renaming" -Status "Complete" -PercentComplete 100
			}

		} elseif ($operation -eq "Set Title to Filename" -or $operation -eq "8") {
			Write-Host "=================== Set Title to Filename ==================" -ForegroundColor blue

			if ($debug -eq $true) {
				foreach ($mkvFile in $mkvFiles) {
					# Run MKVpropedit to remove title tag
					$8peOutput = & $mkvpropedit "$mkvFile" --edit info --set title="$($mkvFile.BaseName)"

					# Modify and display output
					$8peOutputLinesMod = $8peOutput.Trim().Split([Environment]::NewLine)
					foreach ($line in $8peOutputLinesMod) {
						switch ($line) {
							"The file is being analyzed." {
								Write-Host "Analyzing " -NoNewLine
								Write-Host (">" + $mkvFile.BaseName) -ForegroundColor Yellow
							}
							"Done." {
								Write-Host "Done." -ForegroundColor Green
							}
							default { Write-Host $line }
						}
					}
				}
				Write-Host "All files processed successfully!" -ForegroundColor green
			} else {
				$8processed = 0
				Write-Host "Processing " -NoNewLine
				foreach ($mkvFile in $mkvFiles) {
					Write-Progress -Activity "Remove Title Tag" -Status $mkvFile.BaseName -PercentComplete (($8processed / $fileCount) * 100)
					$8processed++
					
					& $mkvpropedit "$mkvFile" --edit info --set title="$($mkvFile.BaseName)" > $null
				}
				Write-Host ">Done" -ForegroundColor green
				Write-Progress -Completed -Activity "Remove Title Tag" -Status "Complete" -PercentComplete 100
			}

		}
	}
}

# Remove temp folder and files
Remove-Item -Path "temp" -Recurse -Force
Write-Host "Temporary folder and its contents deleted"