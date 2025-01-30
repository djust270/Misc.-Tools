# Example dual-window "file explorer" using WinForms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the main form
$mainForm = New-Object System.Windows.Forms.Form
$mainForm.Text = "Dual Pane File Explorer"
$mainForm.Size = New-Object System.Drawing.Size(1200, 700)
$mainForm.StartPosition = "CenterScreen"

# Create a SplitContainer to organize the two explorer views
$splitContainer = New-Object System.Windows.Forms.SplitContainer
$splitContainer.Dock = [System.Windows.Forms.DockStyle]::Fill
$splitContainer.Orientation = [System.Windows.Forms.Orientation]::Vertical
$splitContainer.SplitterWidth = 8  # Width of the splitter bar

# Function to create an Explorer WebBrowser
function New-ExplorerBrowser {
    param (
        [string]$initialPath = "shell:MyComputerFolder"
    )

    # Create a hashtable to store our controls
    $controls = @{}

    # Create panel to host navigation controls and browser
    $hostPanel = New-Object System.Windows.Forms.Panel
    $hostPanel.Dock = [System.Windows.Forms.DockStyle]::Fill

    # Create navigation toolbar
    $navPanel = New-Object System.Windows.Forms.Panel
    $navPanel.Dock = [System.Windows.Forms.DockStyle]::Top
    $navPanel.Height = 25
    
    # Create a container panel for the browser
    $browserContainer = New-Object System.Windows.Forms.Panel
    $browserContainer.Dock = [System.Windows.Forms.DockStyle]::Fill
    
    # Back button
    $controls.backButton = New-Object System.Windows.Forms.Button
    $controls.backButton.Text = "←"
    $controls.backButton.Width = 30
    $controls.backButton.Location = New-Object System.Drawing.Point(0, 0)
    $controls.backButton.Height = 25
    $controls.backButton.Enabled = $false
    
    # Forward button
    $controls.forwardButton = New-Object System.Windows.Forms.Button
    $controls.forwardButton.Text = "→"
    $controls.forwardButton.Width = 30
    $controls.forwardButton.Location = New-Object System.Drawing.Point(35, 0)
    $controls.forwardButton.Height = 25
    $controls.forwardButton.Enabled = $false
    
    # Up button
    $controls.upButton = New-Object System.Windows.Forms.Button
    $controls.upButton.Text = "↑"
    $controls.upButton.Width = 30
    $controls.upButton.Location = New-Object System.Drawing.Point(70, 0)
    $controls.upButton.Height = 25

    # Home button
    $controls.homeButton = New-Object System.Windows.Forms.Button
    $controls.homeButton.Text = "🏡"
    $controls.homeButton.Width = 30
    $controls.homeButton.Location = New-Object System.Drawing.Point(105, 0)
    $controls.homeButton.Height = 25
    
    # Address bar
    $controls.addressBar = New-Object System.Windows.Forms.TextBox
    $controls.addressBar.Location = New-Object System.Drawing.Point(140, 0)
    $controls.addressBar.Height = 25
    $controls.addressBar.Anchor = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
    $controls.addressBar.Width = $hostPanel.Width - 380  # Adjust width dynamically
    
    # Search box
    $controls.searchBox = New-Object System.Windows.Forms.TextBox
    $controls.searchBox.Location = New-Object System.Drawing.Point($($controls.addressBar.Right + 10), 0)
    $controls.searchBox.Height = 25
    $controls.searchBox.Width = 200
    $controls.searchBox.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
    $controls.searchBox.Text = "Search..."
    $controls.searchBox.ForeColor = [System.Drawing.Color]::DarkGray
    
    # Create WebBrowser
    $controls.browser = New-Object System.Windows.Forms.WebBrowser
    $controls.browser.Dock = [System.Windows.Forms.DockStyle]::Fill
    $controls.browser.AllowWebBrowserDrop = $false
    $controls.browser.IsWebBrowserContextMenuEnabled = $true
    $controls.browser.WebBrowserShortcutsEnabled = $true
    $controls.browser.ScriptErrorsSuppressed = $true

    $controls.homeButton.Add_Click({ 
        $controls.browser.Navigate("shell:MyComputerFolder")
    }.GetNewClosure())

    $controls.searchBox.Add_GotFocus({
        if ($controls.searchBox.Text -eq "Search...") {
            $controls.searchBox.Text = ""
            $controls.searchBox.ForeColor = [System.Drawing.Color]::Black
        }
    }.GetNewClosure())

    $controls.searchBox.Add_LostFocus({
        if ([string]::IsNullOrWhiteSpace($controls.searchBox.Text)) {
            $controls.searchBox.Text = "Search..."
            $controls.searchBox.ForeColor = [System.Drawing.Color]::DarkGray
        }
    }.GetNewClosure())

    # Wire up navigation events
    $controls.backButton.Add_Click({
        if ($controls.browser.CanGoBack) {
            $controls.browser.GoBack()
        }
    }.GetNewClosure())
    
    $controls.forwardButton.Add_Click({
        if ($controls.browser.CanGoForward) {
            $controls.browser.GoForward()
        }
    }.GetNewClosure())
    
    $controls.upButton.Add_Click({ 
        try {
            $url = $controls.browser.Url
            if ($url -and $url.LocalPath) {
                $currentPath = $url.LocalPath
                if (Test-Path $currentPath) {
                    $parent = Split-Path $currentPath -Parent
                    if ($parent) {
                        $controls.browser.Navigate($parent)
                    }
                }
            }
        } catch { }
    }.GetNewClosure())
    
    # Update address bar when navigation completes
    $controls.browser.Add_Navigated({
        try {
            if ($controls.browser.Url) {
                if ($controls.browser.Url.Scheme -eq "file") {
                    $controls.addressBar.Text = $controls.browser.Url.LocalPath
                } else {
                    $controls.addressBar.Text = $controls.browser.Url.ToString()
                }
            }
        } catch { }
    }.GetNewClosure())
    
    # Handle address bar navigation
    $controls.addressBar.Add_KeyDown({
        if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
            $path = $controls.addressBar.Text.Trim()
            $path = $controls.addressBar.Text.Trim()
            if (Test-Path $path) {
                $controls.browser.Navigate("file:///" + $path)
            }
            elseif ($path -match '^shell:') {
                $controls.browser.Navigate($path)
            }
            else {
                # Treat as search if not a valid path
                $controls.browser.Navigate("shell:SearchHomeFolder?query=$path")
            }
            $_.SuppressKeyPress = $true
        }
    }.GetNewClosure())

    # Handle search box
    $controls.searchBox.Add_KeyDown({
        if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter -and 
            $controls.searchBox.Text -ne "Search..." -and 
            ![string]::IsNullOrWhiteSpace($controls.searchBox.Text)) {
            
            $searchQuery = $controls.searchBox.Text.Trim()
            $currentPath = if ($controls.browser.Url -and $controls.browser.Url.LocalPath) {
                $controls.browser.Url.LocalPath
            } else {
                "shell:MyComputerFolder"
            }
            $searchResult = Search-Everything -Filter $searchQuery | foreach {
                get-item -literalpath $_ | Select-Object name,directory,LastWriteTime,@{Name="Size(MB)";Expression={"{0:N2} MB" -f ($_.length / 1MB)}}
            } | Out-GridView -Title "Search Results" -PassThru
            if ($searchResult) {
                $folder = $searchResult.Directory
                Write-Verbose "folder $folder" -Verbose
                $controls.browser.Navigate("file:///" + $folder)
            }
            $_.SuppressKeyPress = $true
        }
    }.GetNewClosure())
    
    # Enable/disable navigation buttons based on state
    $controls.browser.Add_CanGoBackChanged({
        $controls.backButton.Enabled = $controls.browser.CanGoBack
    }.GetNewClosure())
    
    $controls.browser.Add_CanGoForwardChanged({
        $controls.forwardButton.Enabled = $controls.browser.CanGoForward
    }.GetNewClosure())

    # Add controls to panels in the correct order
    $navPanel.Controls.AddRange(@(
        $controls.backButton,
        $controls.forwardButton,
        $controls.upButton,
        $controls.homeButton,
        $controls.addressBar,
        $controls.searchBox
    ))

    # Add the browser to its container
    $browserContainer.Controls.Add($controls.browser)

    # Add panels to the host panel in the correct order
    $hostPanel.Controls.Add($browserContainer)
    $hostPanel.Controls.Add($navPanel)
    
    # Initial navigation
    $controls.browser.Navigate($initialPath)
    
    return $hostPanel, $controls.browser
}

# Create and add the two explorer panels
$leftPanel, $leftBrowser = New-ExplorerBrowser
$rightPanel, $rightBrowser = New-ExplorerBrowser

# Add panels to the split container
$splitContainer.Panel1.Controls.Add($leftPanel)
$splitContainer.Panel2.Controls.Add($rightPanel)

# Add the SplitContainer to the main form
$mainForm.Controls.Add($splitContainer)

# Set the SplitContainer initial position
$splitContainer.SplitterDistance = $mainForm.Width / 2

# Create main menu
$mainMenu = New-Object System.Windows.Forms.MenuStrip
$fileMenu = New-Object System.Windows.Forms.ToolStripMenuItem
$fileMenu.Text = "File"

# Add refresh option
$refreshMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$refreshMenuItem.Text = "Refresh"
$refreshMenuItem.Add_Click({
    $leftBrowser.Refresh()
    $rightBrowser.Refresh()
})

# Add exit option
$exitMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exitMenuItem.Text = "Exit"
$exitMenuItem.Add_Click({ $mainForm.Close() })

$fileMenu.DropDownItems.Add($refreshMenuItem)
$fileMenu.DropDownItems.Add($exitMenuItem)
$mainMenu.Items.Add($fileMenu)
$mainForm.MainMenuStrip = $mainMenu
$mainForm.Controls.Add($mainMenu)

# Show the form
[System.Windows.Forms.Application]::EnableVisualStyles()
$mainForm.ShowDialog()
