[System.Console]::WindowWidth = 200
[System.Console]::WindowHeight = 40

$debug = $true

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

# Set paths to MKVToolNix executables
$mkvmerge = "C:\Program Files\MKVToolNix\mkvmerge.exe"
$mkvpropedit = "C:\Program Files\MKVToolNix\mkvpropedit.exe"

# Specify the directory containing JSON files
$jsonFilesDirectory = "temp\"

# Display files for change
[int]$fileCount = 0
Write-Host "===================== Files For Change =====================" -ForegroundColor blue
Get-ChildItem -Filter "*.mkv" | ForEach-Object {
	Write-Host $_.Name
	$fileCount++
}
Write-Host "File Count: $fileCount"

$exit = 0
$currentTrackCountMis = 0
$misMatch = 0
$operation = 0

# Main Code
while ($exit -ne 1) {
	# Get user confirmation
	Write-Host "======================== Operation =========================" -ForegroundColor blue
	$operation = Read-Host -Prompt "Select Operation [Exit(1), Reorder Tracks(2), Language Switcher(3), Track Table(4), Remove Tags(5), Remove Tracks(6), Rename Track(7), Remove Independent Title(8)]"

	if ($operation -eq "exit" -or $operation -eq "1") {
		$exit = 1
	} elseif (($operation -lt 2) -or ($operation -gt 8)) {
		Write-Host "Enter a valid integer input." -ForegroundColor DarkRed
	} else {
		Write-Host ""
		# Create temp folder if it doesn't exist already
		Write-Host "Creating temp Folder" -NoNewLine
		if (!(Test-Path "temp")) {
			[void] (New-Item -ItemType Directory -Name "temp")
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
		Write-Host ">Done " -ForegroundColor Green
		
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
					Write-Host " >Matching" -ForegroundColor Green
				} else {
					Write-Host "All files have matching track counts" -ForegroundColor Green
				}
			}
		}
		
		if ($operation -eq "Reorder Tracks" -or $operation -eq "2") {
			Write-Host "====================== Reorder Tracks ======================" -ForegroundColor blue
			
			$2newTrackOrder = Read-Host -Prompt "Enter the new track order (e.g., 0,1,2,4,3)"
			# Convert user input to MKVmerge format
			$2newTrackOrder = "0:" + $2newTrackOrder -Replace ",\s*", ",0:"

			Write-Host $2newTrackOrder
			pause

			# Ensure "MODIFIED" folder exists
			if (!(Test-Path -Path "MODIFIED")) {
				New-Item -ItemType Directory -Name "MODIFIED"
			}

			# Loop through each MKV file
			foreach ($mkvFile in $mkvFiles) {
				Write-Host ""
				Write-Host "============ Processing file: $mkvFile" -ForegroundColor blue
				Write-Host ""

				# Create a new file name for the output file
				$outputFileName = "$($mkvFile.BaseName)_reordered.mkv"
				
				# Construct the full output file path
				$outputFile = Join-Path -Path "MODIFIED" -ChildPath $outputFileName
				
				# Run MKVmerge to reorder the tracks
				& $mkvmerge -o $outputFile "$mkvFile" --track-order $2newTrackOrder
				
				Write-Host "Reordered tracks and saved to: $outputFile" -ForegroundColor blue
				Write-Host ""
			}

			Write-Host "All files processed successfully!" -ForegroundColor green
			
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
				write-Host "Clearing multi"
				$multi = @()
			}

			Write-Host "number of elements in multi:"$multi.Count
			Write-Host "track count:"$currentTrackCount

			$multi | Format-Table -Autosize -Wrap
			$array | Format-Table -Autosize -Wrap

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
							Write-Host "FALSE" -ForegroundColor DarkRed
							return $false
						}
					}
					#DEBUG Write-Host "Track CLEARED" -ForegroundColor green
				}
				Write-Host "TRUE" -ForegroundColor green
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
					Write-Host "Active track language: $activeLanguage"
					
					$confirm = Read-Host "Swap Language? [Y/N]"
					if ($confirm -eq "Y" -or $confirm -eq "y") {

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
											$selectedAudio= $multiTracks.Name
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
						
						# Recurse through each MKV file and apply changes
						Get-ChildItem -Filter "*.mkv" | ForEach-Object {
							$currentFile = $_.Name
							
							Write-Host "Switching:" $currentFile -ForegroundColor DarkBlue
							
							[int]$index = 0
							foreach ($trackInfo in $array) {
								if (!(NotMultipleOf $index $fileCount)) {
									if ($trackInfo.Type -eq 'audio') {

										$mkvType = "a"
										$mkvNum = $trackInfo.LocalTypeNum

										if ($extraTrack -eq $true) {
											
											# Identify tracks with same default value
											$toDefault = $selectedAudio
											Write-Host "Selected:"$selectedAudio
											
											Write-Host "reference: $mkvType$mkvNum"
											
											# Check for three audio tracks with specific default values
											if ($trackInfo.Default -eq $true) {
												
												& $mkvpropedit $currentFile --edit track:$mkvType$mkvNum --set flag-default=0 #set all tracks default false
												Write-Host "set" $trackInfo.Name "Default FALSE (all)" -ForegroundColor Magenta

												# Modify default settings based on user selection
												if ($trackInfo.Name -eq $toDefault) {
													& $mkvpropedit $currentFile --edit track:$mkvType$mkvNum --set flag-default=1 #set selected Audio track default true
													Write-Host "set" $trackInfo.Name "Default TRUE (selected)" -ForegroundColor Magenta
												} else {
													& $mkvpropedit $currentFile --edit track:$mkvType$mkvNum --set flag-default=0 #set unselected track default false
													Write-Host "set" $trackInfo.Name "Default FALSE" -ForegroundColor Magenta
												}
											} elseif ($trackInfo.Default -eq $false) {
												
												& $mkvpropedit $currentFile --edit track:$mkvType$mkvNum --set flag-default=1 #set all tracks default true
												Write-Host "set" $trackInfo.Name "Default TRUE" -ForegroundColor Magenta

												# Modify default settings based on user selection
												if ($trackInfo.Name -eq $toDefault) {
													& $mkvpropedit $currentFile --edit track:$mkvType$mkvNum --set flag-default=1 #set selected Audio track default true
													Write-Host "set" $trackInfo.Name "Default TRUE" -ForegroundColor Magenta
												} else {
													& $mkvpropedit $currentFile --edit track:$mkvType$mkvNum --set flag-default=0 #set unselected track default false
													Write-Host "set" $trackInfo.Name "Default FALSE" -ForegroundColor Magenta
												}
											}
										
										# No extra tracks
										} elseif ($extraTrack -eq $false) {
											if ($trackInfo.Default -eq $true) {
												
												Write-Host "reference: $mkvType$mkvNum"
												& $mkvpropedit $currentFile --edit track:$mkvType$mkvNum --set flag-default=0 # Set default false
												Write-Host "set" $trackInfo.Name "Default FALSE" -ForegroundColor Magenta

											} elseif ($trackInfo.Default -eq $false) {
												
												Write-Host "reference: $mkvType$mkvNum"
												& $mkvpropedit $currentFile --edit track:$mkvType$mkvNum --set flag-default=1 # Set default true
												Write-Host "set" $trackInfo.Name "Default TRUE" -ForegroundColor Magenta

												if ($trackinfo.Language -eq $activeLanguage -and $multi.Count -ne 0) {
													
													Write-Host "reference: $mkvType$mkvNum"
													& $mkvpropedit $currentFile --edit track:$mkvType$mkvNum --set flag-default=0 # Set default false
													Write-Host "set" $trackInfo.Name "Default FALSE (reverse)" -ForegroundColor Magenta
												}
											}
										}
									} elseif ($trackInfo.Type -eq 'subtitles') {

										$mkvType = "s"
										$mkvNum = $trackInfo.LocalTypeNum

										if ($extraTrack -eq $true) {
											
											# Identify tracks with same default value
											$toDefault = $selectedSubtitle
											Write-Host "Selected:"$selectedSubtitle
											
											Write-Host "reference: $mkvType$mkvNum"
											
											# Check for three subtitle tracks with specific default values
											if ($trackInfo.Default -eq $true) {
												
												& $mkvpropedit $currentFile --edit track:$mkvType$mkvNum --set flag-default=0 #set all tracks default false
												Write-Host "set" $trackInfo.Name "Default FALSE (all)" -ForegroundColor Magenta

												# Modify default settings based on user selection
												if ($trackInfo.Name -eq $toDefault) {
													& $mkvpropedit $currentFile --edit track:$mkvType$mkvNum --set flag-default=1 #set selected Subtitle track default true
													Write-Host "set" $trackInfo.Name "Default TRUE (selected)" -ForegroundColor Magenta
												} else {
													& $mkvpropedit $currentFile --edit track:$mkvType$mkvNum --set flag-default=0 #set unselected track default false
													Write-Host "set" $trackInfo.Name "Default FALSE" -ForegroundColor Magenta
												}
											} elseif ($trackInfo.Default -eq $false) {
												
												& $mkvpropedit $currentFile --edit track:$mkvType$mkvNum --set flag-default=1 #set all tracks default true
												Write-Host "set" $trackInfo.Name "Default TRUE" -ForegroundColor Magenta

												# Modify default settings based on user selection
												if ($trackInfo.Name -eq $toDefault) {
													& $mkvpropedit $currentFile --edit track:$mkvType$mkvNum --set flag-default=1 #set selected Subtitle track default true
													Write-Host "set" $trackInfo.Name "Default TRUE" -ForegroundColor Magenta
												} else {
													& $mkvpropedit $currentFile --edit track:$mkvType$mkvNum --set flag-default=0 #set unselected track default false
													Write-Host "set" $trackInfo.Name "Default FALSE" -ForegroundColor Magenta
												}
											}
										
										# If there are no extra tracks
										} elseif ($extraTrack -eq $false) {
											if ($trackInfo.Default -eq $true) {
												
												Write-Host "reference: $mkvType$mkvNum"
												& $mkvpropedit $currentFile --edit track:$mkvType$mkvNum --set flag-default=0 # Set default false
												Write-Host "set" $trackInfo.Name "Default FALSE" -ForegroundColor Magenta
												
											} elseif ($trackInfo.Default -eq $false) {
												
												Write-Host "reference: $mkvType$mkvNum"
												& $mkvpropedit $currentFile --edit track:$mkvType$mkvNum --set flag-default=1 # Set default true
												Write-Host "set" $trackInfo.Name "Default TRUE" -ForegroundColor Magenta

												if ($trackinfo.Name -ne "Signs & Songs" -and $multi.Count -ne 0) {

													Write-Host "reference: $mkvType$mkvNum"
													& $mkvpropedit $currentFile --edit track:$mkvType$mkvNum --set flag-default=0 # Set default false
													Write-Host "set" $trackInfo.Name "Default FALSE (reverse)" -ForegroundColor Magenta
												}
											}
										}
									}
								}
								$index++
								
							}
						}
					} else {
						$exit = 1
					}
					Write-Host "Successfully changed track defaults from [$activeLanguage]--->[$newLanguage]" -ForegroundColor green
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
			Write-Host "WARNING- " -NoNewLine -ForegroundColor DarkRed
			Write-Host "This Operation Removes ALL Tags from the file." -ForegroundColor Red
			$5Confirmation = Read-Host -Prompt "Continue? [Y/N]"

			Write-Host $5Confirmation

			if ($5Confirmation -eq "Y" -or $5Confirmation -eq "y") {
				
				# Loops through all .mkv files within the current directory
				foreach ($mkvFile in $mkvFiles) {
					& $mkvpropedit "$mkvFile" --tags all:
				}
				
				Write-Host "All files processed successfully!" -ForegroundColor green
			} else {
				$exit = 1
			}
			
		} elseif ($operation -eq "Remove Tracks" -or $operation -eq "6") {
			
			$6tracksToRemove = Read-Host -Prompt "List Tracks to Remove (e.g. 0,3,4)"
			
			# Ensure "MODIFIED" folder exists
			if (!(Test-Path -Path "MODIFIED")) {
				New-Item -ItemType Directory -Name "MODIFIED"
			}
			
			# Loop through each MKV file
			foreach ($mkvFile in $mkvFiles) {
				Write-Host ""
				Write-Host "============ Processing file: $mkvFile" -ForegroundColor blue
				Write-Host ""
				
				# Create a new file name for the output file
				$outputFileName = "$($mkvFile.BaseName)_MODIFIED.mkv"
				
				# Construct the full output file path
				$outputFile = Join-Path -Path "MODIFIED" -ChildPath $outputFileName
				
				# Run MKVmerge to reorder the tracks and create the new file
				& $mkvmerge -o $outputFile --audio-tracks !$6tracksToRemove --video-tracks !$6tracksToRemove --subtitle-tracks !$6tracksToRemove "$mkvFile"
				
				Write-Host "Removed tracks and saved to: $outputFile" -ForegroundColor blue
				Write-Host ""
			}
			Write-Host "All files processed successfully!" -ForegroundColor green

		} elseif ($operation -eq "Rename Track" -or $operation -eq "7") {

			Write-Host "======================= Rename Track =======================" -ForegroundColor blue
			$7renameTrack = Read-Host -Prompt "Which track do you want to rename? (e.g. v1,a2)"
			$7newName = Read-Host -Prompt "Enter the new name"
			Write-Host ""

			# Loop through each MKV file
			if ($debug -eq $true) {
				Write-Host "Editing Files:"
				foreach ($mkvFile in $mkvFiles) {
					# Run MKVpropedit to rename the desired track
					$peOutput = & $mkvpropedit $mkvFile --edit track:$7renameTrack --set name="$7newName"

					# Modify and display output
					$peOutputLinesMod = $peOutput.Trim().Split([Environment]::NewLine)
					foreach ($line in $peOutputLinesMod) {
						switch ($line) {
						"The file is being analyzed." {
							Write-Host "Analyzing " -NoNewLine
							Write-Host (">" + $mkvFile.BaseName) -ForegroundColor Yellow
						}
						default { Write-Host $line }
						}
					}
					Write-Host ""
				}
				Write-Host "All files processed successfully!" -ForegroundColor green
			} else {
				Write-Host "Editing Files " -NoNewLine
				foreach ($mkvFile in $mkvFiles) {
					& $mkvpropedit $mkvFile --edit track:$7renameTrack --set name="$7newName" > $null
				}
				Write-Host ">Done" -ForegroundColor green
			}

		} elseif ($operation -eq "Remove Independent Title" -or $operation -eq "8") {
			Write-Host "Note- " -NoNewLine -ForegroundColor Yellow
			Write-Host "This operation will set the filename to the mkv title"
			$8Confirmation = Read-Host -Prompt "Continue? [Y/N]"

			if ($8Confirmation -eq "Y" -or $8Confirmation -eq "y") {
				
				# Loops through all .mkv files within the current directory
				foreach ($mkvFile in $mkvFiles) {
					& $mkvpropedit "$mkvFile" -d title
				}
				
				Write-Host "All files processed successfully!" -ForegroundColor green
			} else {
				$exit = 1
			}

		}
	}
}

# Remove temp folder and files
Remove-Item -Path "temp" -Recurse -Force
Write-Host "Temporary folder and its contents deleted"