
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Stitch API Key - 붙여넣기'
$form.Size = New-Object System.Drawing.Size(580, 260)
$form.StartPosition = 'CenterScreen'
$form.TopMost = $true
$form.Font = New-Object System.Drawing.Font('Malgun Gothic', 10)

$label = New-Object System.Windows.Forms.Label
$label.Text = "Stitch 설정에서 복사한 키를 아래 칸에 붙여넣으세요.`r`n(칸을 누르고 Ctrl+V  또는  [클립보드에서 붙여넣기] 버튼)"
$label.Location = New-Object System.Drawing.Point(16, 14)
$label.Size = New-Object System.Drawing.Size(540, 46)
$form.Controls.Add($label)

$box = New-Object System.Windows.Forms.TextBox
$box.Location = New-Object System.Drawing.Point(16, 66)
$box.Size = New-Object System.Drawing.Size(530, 28)
$box.UseSystemPasswordChar = $true
$form.Controls.Add($box)

$show = New-Object System.Windows.Forms.CheckBox
$show.Text = '키 보이기'
$show.Location = New-Object System.Drawing.Point(16, 104)
$show.Add_CheckedChanged({ $box.UseSystemPasswordChar = -not $show.Checked })
$form.Controls.Add($show)

$paste = New-Object System.Windows.Forms.Button
$paste.Text = '클립보드에서 붙여넣기'
$paste.Location = New-Object System.Drawing.Point(16, 146)
$paste.Size = New-Object System.Drawing.Size(210, 38)
$paste.Add_Click({ $box.Text = ([System.Windows.Forms.Clipboard]::GetText()).Trim() })
$form.Controls.Add($paste)

$save = New-Object System.Windows.Forms.Button
$save.Text = '저장'
$save.Location = New-Object System.Drawing.Point(406, 146)
$save.Size = New-Object System.Drawing.Size(140, 38)
$save.Add_Click({
  $key = $box.Text.Trim()
  if ($key.Length -lt 20 -or $key -match '\s') {
    [System.Windows.Forms.MessageBox]::Show('키 모양이 아닙니다. Stitch 설정에서 키를 다시 복사해 주세요.', 'Stitch API Key') | Out-Null
    return
  }
  [Environment]::SetEnvironmentVariable('STITCH_API_KEY', $key, 'User')
  $masked = $key.Substring(0, 4) + '...' + $key.Substring($key.Length - 4)
  [System.Windows.Forms.MessageBox]::Show("저장했습니다 ($masked).`r`n이제 Claude 앱을 완전히 껐다 켜 주세요.", 'Stitch API Key') | Out-Null
  $form.Close()
})
$form.Controls.Add($save)
$form.AcceptButton = $save
$form.Add_Shown({ $form.Activate(); $box.Focus() })
[void]$form.ShowDialog()
