#############################
#
# MatchLogger
#
#############################

###### Variables ############

$raspi__scoreboard_ip = "192.168.8.179"
$raspi__shotclock_ip = "192.168.8.178"
$polltime_secs = 1  # seconds
$basedir = "C:\MatchLogger\"
$testing = $true  # normally: $false

###### End Variables ########

##############################
# Do not edit below          #
##############################

$current_date = Get-Date -format "yyyy-MM-dd"
$current_time = Get-Date -format "HHmmss"
$logdir = "$basedir\$current_date\"

$logfilename = Get-Date -format "yyyy-MM-dd_HHmmss"
$logfile = "$logdir$logfilename.csv"

if (!(Test-Path $logdir)) {
    New-Item -itemType Directory -Path $logdir
}
else {
    write-host "Directory '$logdir' already exists, skipping creation..."
}

##############################
# Init                       #
##############################

$headerline = @()
$headerline += "Date"
$headerline += "Time"
$headerline += "ScoreStatus"
$headerline += "HomeScore"
$headerline += "GuestScore"
$headerline += "ScoreChanged"

$last_Home_Score = 0
$last_Guest_Score = 0

##############################
# Construct URL's            #
##############################

$url_score = "http://$raspi__scoreboard_ip/scoreboard/score"
$url_time = "http://$raspi__scoreboard_ip/timeclock/time"
$url_shotclock = "http://$raspi__shotclock_ip/shotclock/time"

##############################
# Main loop                  #
##############################

while ($true) {
    
    ##############################
    #region Init per cycle
    ##############################

    $logline = @{}

    $logline2 = @()
    $logline_time = @()
    $logline_shotclock = @()
    $logline_score = @()

    $score_changed = $false
    #endregion Init per cycle

    ######################################
    #region Set date and time for the request
    ######################################

    $logline.Add("date", (Get-Date -format "yyyy-MM-dd"))
    $logline.Add("time", (Get-Date -format "HH:mm:ss.fff"))

    #endregion Set date and time for the request
    
    ######################################
    #region Get the scoreboard match time left
    ######################################
    if ($testing) {
        # Got this as a sample...
        $answer_time = "{""status"": ""OK"", ""second"": 17, ""minute"": 15}"
    }
    else {
        $answer_time = Invoke-WebRequest $url_time
    }
    $result_time = ConvertFrom-Json $answer_time

    $logline_time = $result_time.status

    if ($result_time.status -eq "OK") {
        $logline.Add("clock_digits_left", $result_time.minute)
        $logline.Add("clock_digits_right", $result_time.second)
    }
    else {
        #Geen tijd...

        $logline.Add("clock_digits_left", "")
        $logline.Add("clock_digits_right", "")
    }
    #endregion Get the scoreboard match time left

    ######################################
    #region Get the scoreboard score      
    ######################################

    if ($testing) {
        # Got this as a sample...
        $answer_score = "{""status"": ""OK"", ""home"": 18, ""guest"": 13}"
    }
    else {
        $answer_score = Invoke-WebRequest $url_score
    }
    $result_score = ConvertFrom-Json $answer_score

    $logline_score += $result_score.status
    $score_changed_text = ""

    if ($result_score.status -eq "OK") {
        # There is a valid response
        $logline.Add("score_home", $result_score.Home)
        $logline.Add("score_guest", $result_score.Guest)

        # -or (($i % 3) -eq 2)
        if (($last_Home_Score -ne $result_score.Home) -or ($last_Guest_Score -ne $result_score.Guest)) {
            $score_changed = $true
            $score_changed_text = "Goal"
            $foreGroundColor = "Yellow"
            $logline.Add("score_changed", "1")
        }
        else {
            $foreGroundColor = "Green"
            $logline.Add("score_changed", "0")
        }

        $logline_score += $score_changed

        $last_Home_Score = $result_score.Home
        $last_Guest_Score = $result_score.Guest
    }
    else {
        # No valid response, discard
        $foreGroundColor = "Red"

        $logline.Add("score_home", "")
        $logline.Add("score_guest", "")
    }

    #endregion Get the scoreboard score      
    
    ######################################
    #region Get the scoreboard score     #
    ######################################

    if ($testing) {
        # Got this as a sample...
        $answer_shotclock = "{""status"": ""OK"", ""time"": 24}"
    }
    else {
        #$answer_shotclock = Invoke-WebRequest $url_shotclock
    }
    $result_shotclock = ConvertFrom-Json $answer_shotclock

    if ($result_shotclock.status -eq "OK") {
        $logline_shotclock += $result_shotclock.time
        $logline.Add("shotclock", $result_shotclock.time)

    }
    else {
        #Geen tijd...
        $logline.Add("shotclock", "")
    }

    #endregion Get the scoreboard score


    ######################################
    #region Construct object
    ######################################

    #$total_line_score =  $logline2[0], $logline2[1], "- Home:", $result_score.Home, "- Guest:", $result_score.Guest, $score_changed_text

    $logline_object = New-Object psobject -Property $logline; $o

    #endregion Construct object

    ######################################
    #region Print values
    ######################################

    Write-Host -NoNewline $logline_object.date, $logline_object.time, " | ",  $logline_object.clock_digits_left, ":", $logline_object.clock_digits_right, " | ", $logline_object.score_home, " - ", $logline_object.score_guest, " | ", $logline_object.shotclock, $score_changed_text -foregroundcolor $foreGroundColor
    Write-host

    #endregion Print values

    ######################################
    #region Store values
    ######################################

    $logline_object |Select date, time, clock_digits_left, clock_digits_right, score_home, score_guest, shotclock | Export-Csv -Path $logfile -Delimiter "|" -NoTypeInformation -NoClobber -Append

    #endregion Store values

    sleep -Milliseconds ($polltime_secs * 1000)

}
