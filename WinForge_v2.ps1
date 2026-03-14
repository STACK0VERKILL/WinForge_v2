# .SYNOPSIS
#     WinForge - Herramienta grafica para modificar imagenes ISO
#     Author: Stack0verkill  |  Version: 2.2 (2026)
#     FIX: 0xC0000135 + ScriptRoot nulo en irm/iex

#Requires -Version 5.1
Set-StrictMode -Version Latest
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# ---------------------------------------------
#  FIX DEFINITIVO: ScriptRoot compatible con iex
#  $MyInvocation.MyCommand.Definition via iex devuelve
#  el string del comando (ej: 'irm "https..."') no una ruta.
#  Se detecta si es una ruta valida; si no, se usa carpeta fija.
# ---------------------------------------------
$_def = $MyInvocation.MyCommand.Definition
$_isValidPath = $false
try {
    if ($_def -and $_def.Length -lt 300) {
        $_isValidPath = [System.IO.Path]::IsPathRooted($_def) -and (Test-Path $_def -ErrorAction SilentlyContinue)
    }
} catch {}

$Global:ScriptRoot = if ($_isValidPath) {
    Split-Path -Parent $_def
} else {
    "$env:USERPROFILE\WinForge"
}

if (-not (Test-Path $Global:ScriptRoot)) {
    New-Item -ItemType Directory -Path $Global:ScriptRoot -Force | Out-Null
}

# ---------------------------------------------
#  VARIABLES GLOBALES
# ---------------------------------------------
$Global:ISOPath       = $null
$Global:WorkDir       = $null
$Global:MountedDrive  = $null
$Global:ToolsDir      = "$Global:ScriptRoot\tools"
$Global:OscdimgPath   = "$Global:ToolsDir\oscdimg.exe"
$Global:XorrisoPath   = "$Global:ToolsDir\xorriso.exe"
$Global:XorrIsoBinDir = "$Global:ToolsDir\xorriso_bin"
$Global:BuildWindow   = $null
$Global:BuildLog      = $null
$Global:BuildProg     = $null
$Global:BuildStatus   = $null

if (-not (Test-Path $Global:ToolsDir)) {
    New-Item -ItemType Directory -Path $Global:ToolsDir -Force | Out-Null
}

# ---------------------------------------------
#  XAML - INTERFAZ PRINCIPAL
# ---------------------------------------------
[xml]$XAML = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="WinForge | Stack0verkill v2.2"
    Height="720" Width="860"
    MinHeight="660" MinWidth="800"
    WindowStartupLocation="CenterScreen"
    Background="#1E1E2E"
    FontFamily="Segoe UI">
    <Window.Resources>
        <Style x:Key="BtnPrimary" TargetType="Button">
            <Setter Property="Background" Value="#89B4FA"/>
            <Setter Property="Foreground" Value="#1E1E2E"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Padding" Value="10,7"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#B4BEFE"/></Trigger>
                            <Trigger Property="IsEnabled" Value="False"><Setter Property="Background" Value="#45475A"/><Setter Property="Foreground" Value="#6C7086"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="BtnAction" TargetType="Button" BasedOn="{StaticResource BtnPrimary}">
            <Setter Property="Background" Value="#A6E3A1"/>
        </Style>
        <Style x:Key="BtnDanger" TargetType="Button" BasedOn="{StaticResource BtnPrimary}">
            <Setter Property="Background" Value="#F38BA8"/>
        </Style>
        <Style x:Key="BtnSpecial" TargetType="Button" BasedOn="{StaticResource BtnPrimary}">
            <Setter Property="Background" Value="#CBA6F7"/>
        </Style>
    </Window.Resources>
    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="110"/>
        </Grid.RowDefinitions>
        <StackPanel Grid.Row="0" Margin="0,0,0,14">
            <TextBlock Text="WINFORGE" FontSize="22" FontWeight="Bold" Foreground="#CDD6F4" HorizontalAlignment="Center"/>
            <TextBlock Text="Modificacion, recompilacion y automatizacion de imagenes ISO" FontSize="11" Foreground="#6C7086" HorizontalAlignment="Center" Margin="0,2,0,0"/>
            <TextBlock Text="Hecho por Stack0verkill  |  v2.2 - FIX 0xC0000135" FontSize="10" Foreground="#CBA6F7" HorizontalAlignment="Center" Margin="0,3,0,0" FontStyle="Italic"/>
            <Separator Background="#313244" Margin="0,8,0,0"/>
        </StackPanel>
        <Border Grid.Row="1" Background="#313244" CornerRadius="8" Padding="14,10" Margin="0,0,0,10">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" Text="ISO:" Foreground="#CDD6F4" VerticalAlignment="Center" Margin="0,0,10,0" FontWeight="SemiBold"/>
                <TextBox Grid.Column="1" x:Name="TxtISOPath" Background="#1E1E2E" Foreground="#A6E3A1" BorderThickness="1" BorderBrush="#45475A" IsReadOnly="True" VerticalAlignment="Center" Padding="8,5" FontSize="12" Text="Ningun archivo seleccionado..."/>
                <Button Grid.Column="2" x:Name="BtnSelectISO" Content="[ISO]  Seleccionar ISO" Style="{StaticResource BtnPrimary}" Margin="10,0,0,0" Width="155"/>
            </Grid>
        </Border>
        <Grid Grid.Row="2" Margin="0,0,0,6">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Button Grid.Column="0" x:Name="BtnMount" Content="[!]  Montar ISO" Style="{StaticResource BtnPrimary}" IsEnabled="False" Margin="0,0,5,0" Height="38"/>
            <Button Grid.Column="1" x:Name="BtnAddFile" Content="[F]  Agregar archivo" Style="{StaticResource BtnAction}" IsEnabled="False" Margin="5,0,5,0" Height="38"/>
            <Button Grid.Column="2" x:Name="BtnAddFolder" Content="[DIR]  Agregar carpeta" Style="{StaticResource BtnAction}" IsEnabled="False" Margin="5,0,5,0" Height="38"/>
            <Button Grid.Column="3" x:Name="BtnRecompile" Content="[BUILD]  Recompilar ISO" Style="{StaticResource BtnDanger}" IsEnabled="False" Margin="5,0,0,0" Height="38"/>
        </Grid>
        <Grid Grid.Row="3" Margin="0,0,0,10">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Button Grid.Column="0" x:Name="BtnGenUnattend" Content="[XML]  Generar autounattend.xml" Style="{StaticResource BtnSpecial}" Margin="0,0,5,0" Height="36"/>
            <TextBlock Grid.Column="1" x:Name="TxtUnattendStatus" Text="Sin autounattend.xml generado" Foreground="#6C7086" FontSize="11" VerticalAlignment="Center" Margin="10,0,0,0"/>
        </Grid>
        <Border Grid.Row="4" Background="#313244" CornerRadius="8" Padding="2">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <TextBlock Grid.Row="0" Text="[LIST]  Archivos / Carpetas agregados" Foreground="#CDD6F4" FontWeight="SemiBold" VerticalAlignment="Center" Margin="12,8,12,6"/>
                <Separator Grid.Row="0" VerticalAlignment="Bottom" Background="#45475A" Margin="0,30,0,0"/>
                <ListBox Grid.Row="1" x:Name="LstFiles" Background="#1E1E2E" BorderThickness="0" Foreground="#CDD6F4" FontSize="12" Margin="4" ScrollViewer.HorizontalScrollBarVisibility="Auto">
                    <ListBox.ItemContainerStyle>
                        <Style TargetType="ListBoxItem">
                            <Setter Property="Padding" Value="8,4"/>
                            <Setter Property="Foreground" Value="#CDD6F4"/>
                            <Style.Triggers>
                                <Trigger Property="IsSelected" Value="True"><Setter Property="Background" Value="#45475A"/></Trigger>
                                <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#313244"/></Trigger>
                            </Style.Triggers>
                        </Style>
                    </ListBox.ItemContainerStyle>
                </ListBox>
                <Border Grid.Row="2" Background="#1E1E2E" CornerRadius="0,0,6,6" Padding="12,6">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock x:Name="TxtFileCount" Text="0 elementos agregados" Foreground="#6C7086" FontSize="11"/>
                        <Button x:Name="BtnClearList" Content="Limpiar lista" Background="Transparent" BorderThickness="0" Foreground="#F38BA8" FontSize="11" Cursor="Hand" Margin="16,0,0,0" Padding="0" VerticalAlignment="Center"/>
                    </StackPanel>
                </Border>
            </Grid>
        </Border>
        <Border Grid.Row="5" Background="#313244" CornerRadius="8" Padding="14,10" Margin="0,10,0,10">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <TextBlock Grid.Row="0" x:Name="TxtStatus" Text="Listo. Seleccione una ISO o genere un autounattend.xml." Foreground="#CDD6F4" FontSize="12" Margin="0,0,0,6"/>
                <ProgressBar Grid.Row="1" x:Name="ProgressBar" Height="8" Minimum="0" Maximum="100" Value="0" Background="#1E1E2E" BorderThickness="0">
                    <ProgressBar.Foreground>
                        <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                            <GradientStop Color="#89B4FA" Offset="0"/>
                            <GradientStop Color="#A6E3A1" Offset="1"/>
                        </LinearGradientBrush>
                    </ProgressBar.Foreground>
                </ProgressBar>
            </Grid>
        </Border>
        <Border Grid.Row="6" Background="#181825" CornerRadius="8" BorderBrush="#313244" BorderThickness="1">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <TextBlock Grid.Row="0" Text="[LOG]  Log de operaciones" Foreground="#6C7086" FontSize="11" Margin="10,6,0,4"/>
                <ScrollViewer Grid.Row="1" x:Name="LogScroller" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                    <TextBlock x:Name="TxtLog" Foreground="#A6ADC8" FontSize="11" FontFamily="Consolas" Margin="10,0,10,8" TextWrapping="Wrap"/>
                </ScrollViewer>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

# ---------------------------------------------
#  XAML - VENTANA GENERADOR AUTOUNATTEND
# ---------------------------------------------
[xml]$XAML_Unattend = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Generar autounattend.xml"
    Height="620" Width="500"
    WindowStartupLocation="CenterOwner"
    ResizeMode="NoResize"
    Background="#1E1E2E"
    FontFamily="Segoe UI">
    <Window.Resources>
        <Style x:Key="Lbl" TargetType="TextBlock">
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Margin" Value="0,0,0,4"/>
        </Style>
        <Style x:Key="Txt" TargetType="TextBox">
            <Setter Property="Background" Value="#313244"/>
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="BorderBrush" Value="#45475A"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="CaretBrush" Value="#CDD6F4"/>
        </Style>
        <Style x:Key="Pwd" TargetType="PasswordBox">
            <Setter Property="Background" Value="#313244"/>
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="BorderBrush" Value="#45475A"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="CaretBrush" Value="#CDD6F4"/>
        </Style>
    </Window.Resources>
    <Grid Margin="24">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <StackPanel Grid.Row="0" Margin="0,0,0,20">
            <TextBlock Text="[XML]  Configuracion de instalacion" FontSize="16" FontWeight="Bold" Foreground="#CBA6F7"/>
            <TextBlock Text="Se generara autounattend.xml en la raiz de la ISO" FontSize="11" Foreground="#6C7086" Margin="0,4,0,0"/>
            <TextBlock Text="Hecho por Stack0verkill" FontSize="10" Foreground="#CBA6F7" HorizontalAlignment="Center" Margin="0,3,0,0" FontStyle="Italic"/>
            <Separator Background="#313244" Margin="0,8,0,0"/>
        </StackPanel>
        <StackPanel Grid.Row="1" Margin="0,0,0,14">
            <TextBlock Text="[USER]  Nombre de usuario" Style="{StaticResource Lbl}"/>
            <TextBox x:Name="TxtUser" Style="{StaticResource Txt}" MaxLength="20" Text="Usuario"/>
        </StackPanel>
        <StackPanel Grid.Row="2" Margin="0,0,0,14">
            <TextBlock Text="[PASS]  Contrasena" Style="{StaticResource Lbl}"/>
            <PasswordBox x:Name="PwdPass" Style="{StaticResource Pwd}"/>
        </StackPanel>
        <StackPanel Grid.Row="3" Margin="0,0,0,14">
            <TextBlock Text="[PC]  Nombre del equipo (ComputerName)" Style="{StaticResource Lbl}"/>
            <TextBox x:Name="TxtComputer" Style="{StaticResource Txt}" MaxLength="15" Text="PC"/>
            <TextBlock Text="Maximo 15 caracteres, sin espacios ni caracteres especiales" Foreground="#6C7086" FontSize="10" Margin="0,3,0,0"/>
        </StackPanel>
        <StackPanel Grid.Row="4" Margin="0,0,0,14">
            <TextBlock Text="[WIN]  Version de Windows" Style="{StaticResource Lbl}"/>
            <ComboBox x:Name="CmbEdition" Background="#313244" Foreground="#CDD6F4" BorderBrush="#45475A" FontSize="13" Padding="8,6">
                <ComboBoxItem Content="Windows 11 Home" Tag="home"/>
                <ComboBoxItem Content="Windows 11 Pro" Tag="pro" IsSelected="True"/>
                <ComboBoxItem Content="Windows 11 Enterprise" Tag="enterprise"/>
                <ComboBoxItem Content="Windows 10 Home" Tag="home"/>
                <ComboBoxItem Content="Windows 10 Pro" Tag="pro"/>
            </ComboBox>
        </StackPanel>
        <Border Grid.Row="5" Background="#313244" CornerRadius="6" Padding="10,8" Margin="0,0,0,10">
            <TextBlock TextWrapping="Wrap" FontSize="11" Foreground="#A6ADC8">
                Se aplicaran automaticamente: bypass de red, eliminacion de bloatware,
                desactivacion de Copilot, OneDrive, Cortana, Teams, Xbox, widgets,
                Bing en busqueda, contrasena sin expiracion y menu inicio vacio.
            </TextBlock>
        </Border>
        <StackPanel Grid.Row="7" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
            <Button x:Name="BtnCancel" Content="Cancelar" Width="100" Height="36" Margin="0,0,10,0" Background="#45475A" Foreground="#CDD6F4" BorderThickness="0" Cursor="Hand" FontSize="13">
                <Button.Template>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="10,7">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#585B70"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Button.Template>
            </Button>
            <Button x:Name="BtnGenerate" Content="[OK]  Generar XML" Width="140" Height="36" Background="#CBA6F7" Foreground="#1E1E2E" BorderThickness="0" Cursor="Hand" FontSize="13" FontWeight="SemiBold">
                <Button.Template>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="10,7">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#D4BAFF"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Button.Template>
            </Button>
        </StackPanel>
    </Grid>
</Window>
"@

# ---------------------------------------------
#  XAML - VENTANA PROGRESO COMPILACION
# ---------------------------------------------
[xml]$XAML_Build = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Compilando ISO..."
    Height="340" Width="560"
    WindowStartupLocation="CenterOwner"
    ResizeMode="NoResize"
    Background="#1E1E2E"
    FontFamily="Segoe UI">
    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <StackPanel Grid.Row="0" Margin="0,0,0,12">
            <TextBlock Text="[BUILD]  Compilando nueva ISO" FontSize="15" FontWeight="Bold" Foreground="#F38BA8"/>
            <TextBlock Text="Hecho por Stack0verkill  |  v2.2" FontSize="10" Foreground="#CBA6F7" HorizontalAlignment="Center" Margin="0,2,0,0" FontStyle="Italic"/>
            <Separator Background="#313244" Margin="0,8,0,0"/>
        </StackPanel>
        <Grid Grid.Row="1" Margin="0,0,0,8">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock Grid.Column="0" x:Name="BuildStatusTxt" Text="Iniciando..." Foreground="#CDD6F4" FontSize="12" VerticalAlignment="Center"/>
            <TextBlock Grid.Column="1" x:Name="BuildPctTxt" Text="0%" Foreground="#89B4FA" FontSize="14" FontWeight="Bold" VerticalAlignment="Center" Margin="10,0,0,0"/>
        </Grid>
        <ProgressBar Grid.Row="2" x:Name="BuildProgressBar" Height="10" Minimum="0" Maximum="100" Value="0" Background="#313244" BorderThickness="0" Margin="0,0,0,12">
            <ProgressBar.Foreground>
                <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                    <GradientStop Color="#F38BA8" Offset="0"/>
                    <GradientStop Color="#CBA6F7" Offset="0.5"/>
                    <GradientStop Color="#89B4FA" Offset="1"/>
                </LinearGradientBrush>
            </ProgressBar.Foreground>
        </ProgressBar>
        <Border Grid.Row="3" Background="#181825" CornerRadius="8" BorderBrush="#313244" BorderThickness="1">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <TextBlock Grid.Row="0" Text="[LOG]  Salida en tiempo real" Foreground="#6C7086" FontSize="10" Margin="8,5,0,3"/>
                <ScrollViewer Grid.Row="1" x:Name="BuildLogScroller" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                    <TextBlock x:Name="BuildLogTxt" Foreground="#A6ADC8" FontSize="11" FontFamily="Consolas" Margin="8,0,8,6" TextWrapping="Wrap"/>
                </ScrollViewer>
            </Grid>
        </Border>
        <Button Grid.Row="4" x:Name="BuildCloseBtn" Content="Cerrar" Width="100" Height="32" HorizontalAlignment="Right" Margin="0,10,0,0" IsEnabled="False" Background="#45475A" Foreground="#6C7086" BorderThickness="0" Cursor="Hand" FontSize="12">
            <Button.Template>
                <ControlTemplate TargetType="Button">
                    <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="10,5">
                        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <ControlTemplate.Triggers>
                        <Trigger Property="IsEnabled" Value="True">
                            <Setter Property="Background" Value="#A6E3A1"/>
                            <Setter Property="Foreground" Value="#1E1E2E"/>
                        </Trigger>
                        <Trigger Property="IsMouseOver" Value="True">
                            <Setter Property="Background" Value="#B4BEFE"/>
                            <Setter Property="Foreground" Value="#1E1E2E"/>
                        </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Button.Template>
        </Button>
    </Grid>
</Window>
"@

# ---------------------------------------------
#  INSTANCIAR VENTANA PRINCIPAL
# ---------------------------------------------
$Reader            = [System.Xml.XmlNodeReader]::new($XAML)
$Window            = [Windows.Markup.XamlReader]::Load($Reader)
$TxtISOPath        = $Window.FindName("TxtISOPath")
$BtnSelectISO      = $Window.FindName("BtnSelectISO")
$BtnMount          = $Window.FindName("BtnMount")
$BtnAddFile        = $Window.FindName("BtnAddFile")
$BtnAddFolder      = $Window.FindName("BtnAddFolder")
$BtnRecompile      = $Window.FindName("BtnRecompile")
$BtnGenUnattend    = $Window.FindName("BtnGenUnattend")
$TxtUnattendStatus = $Window.FindName("TxtUnattendStatus")
$LstFiles          = $Window.FindName("LstFiles")
$TxtFileCount      = $Window.FindName("TxtFileCount")
$BtnClearList      = $Window.FindName("BtnClearList")
$TxtStatus         = $Window.FindName("TxtStatus")
$ProgressBar       = $Window.FindName("ProgressBar")
$TxtLog            = $Window.FindName("TxtLog")
$LogScroller       = $Window.FindName("LogScroller")

# ---------------------------------------------
#  HELPERS DE UI
# ---------------------------------------------
function Write-UILog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $prefix = switch ($Level) {
        "OK"    { "[OK]"   }
        "WARN"  { "[WARN]" }
        "ERROR" { "[ERR]"  }
        default { "-"      }
    }
    $line = "[$timestamp] $prefix  $Message`n"
    $Window.Dispatcher.Invoke([action]{ $TxtLog.Text += $line; $LogScroller.ScrollToEnd() })
}

function Set-Status {
    param([string]$Message, [int]$Progress = -1)
    $Window.Dispatcher.Invoke([action]{
        $TxtStatus.Text = $Message
        if ($Progress -ge 0) { $ProgressBar.Value = $Progress }
    })
}

function Update-FileCount {
    $count = $LstFiles.Items.Count
    $TxtFileCount.Text = "$count elemento$(if($count -ne 1){'s'}) agregado$(if($count -ne 1){'s'})"
}

function Open-BuildWindow {
    $ReaderB        = [System.Xml.XmlNodeReader]::new($XAML_Build)
    $WinB           = [Windows.Markup.XamlReader]::Load($ReaderB)
    $WinB.Owner     = $Window
    $Global:BuildWindow = $WinB
    $Global:BuildLog    = $WinB.FindName("BuildLogTxt")
    $Global:BuildProg   = $WinB.FindName("BuildProgressBar")
    $Global:BuildStatus = $WinB.FindName("BuildStatusTxt")
    $WinB.FindName("BuildCloseBtn").Add_Click({ $WinB.Close() })
    $WinB.Show()
}

# ---------------------------------------------
#  PLANTILLA INTERNA AUTOUNATTEND
# ---------------------------------------------
$Global:UnatemBase = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
	<settings pass="offlineServicing"></settings>
	<settings pass="windowsPE">
		<component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
			<UILanguage>es-ES</UILanguage>
		</component>
		<component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
			<UserData>
				<ProductKey>
					<Key>VK7JG-NPHTM-C97JM-9MPGT-3V66T</Key>
					<WillShowUI>OnError</WillShowUI>
				</ProductKey>
				<AcceptEula>true</AcceptEula>
			</UserData>
			<UseConfigurationSet>false</UseConfigurationSet>
		</component>
	</settings>
	<settings pass="generalize"></settings>
	<settings pass="specialize">
		<component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
			<ComputerName>PC</ComputerName>
		</component>
		<component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
			<RunSynchronous>
				<RunSynchronousCommand wcm:action="add">
					<Order>1</Order>
					<Path>powershell.exe -WindowStyle "Normal" -NoProfile -Command "$xml = [xml]::new(); $xml.Load('C:\Windows\Panther\unattend.xml'); $sb = [scriptblock]::Create( $xml.unattend.Extensions.ExtractScript ); Invoke-Command -ScriptBlock $sb -ArgumentList $xml;"</Path>
				</RunSynchronousCommand>
				<RunSynchronousCommand wcm:action="add">
					<Order>2</Order>
					<Path>powershell.exe -WindowStyle "Normal" -ExecutionPolicy "Unrestricted" -NoProfile -File "C:\Windows\Setup\Scripts\Specialize.ps1"</Path>
				</RunSynchronousCommand>
				<RunSynchronousCommand wcm:action="add">
					<Order>3</Order>
					<Path>reg.exe load "HKU\DefaultUser" "C:\Users\Default\NTUSER.DAT"</Path>
				</RunSynchronousCommand>
				<RunSynchronousCommand wcm:action="add">
					<Order>4</Order>
					<Path>powershell.exe -WindowStyle "Normal" -ExecutionPolicy "Unrestricted" -NoProfile -File "C:\Windows\Setup\Scripts\DefaultUser.ps1"</Path>
				</RunSynchronousCommand>
				<RunSynchronousCommand wcm:action="add">
					<Order>5</Order>
					<Path>reg.exe unload "HKU\DefaultUser"</Path>
				</RunSynchronousCommand>
			</RunSynchronous>
		</component>
	</settings>
	<settings pass="auditSystem"></settings>
	<settings pass="auditUser"></settings>
	<settings pass="oobeSystem">
		<component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
			<InputLocale>0c0a:0000040a</InputLocale>
			<SystemLocale>es-ES</SystemLocale>
			<UILanguage>es-ES</UILanguage>
			<UserLocale>es-ES</UserLocale>
		</component>
		<component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
			<UserAccounts>
				<LocalAccounts>
					<LocalAccount wcm:action="add">
						<n>Usuario</n>
						<DisplayName></DisplayName>
						<Group>Administrators</Group>
						<Password>
							<Value></Value>
							<PlainText>true</PlainText>
						</Password>
					</LocalAccount>
				</LocalAccounts>
			</UserAccounts>
			<AutoLogon>
				<Username>Usuario</Username>
				<Enabled>true</Enabled>
				<LogonCount>1</LogonCount>
				<Password>
					<Value></Value>
					<PlainText>true</PlainText>
				</Password>
			</AutoLogon>
			<OOBE>
				<ProtectYourPC>3</ProtectYourPC>
				<HideEULAPage>true</HideEULAPage>
				<HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
				<HideOnlineAccountScreens>false</HideOnlineAccountScreens>
			</OOBE>
			<FirstLogonCommands>
				<SynchronousCommand wcm:action="add">
					<Order>1</Order>
					<CommandLine>powershell.exe -WindowStyle "Normal" -ExecutionPolicy "Unrestricted" -NoProfile -File "C:\Windows\Setup\Scripts\FirstLogon.ps1"</CommandLine>
				</SynchronousCommand>
			</FirstLogonCommands>
		</component>
	</settings>
	<Extensions xmlns="https://schneegans.de/windows/unattend-generator/">
		<ExtractScript>
param( [xml] $Document );
foreach( $file in $Document.unattend.Extensions.File ) {
    $path = [System.Environment]::ExpandEnvironmentVariables( $file.GetAttribute( 'path' ) );
    mkdir -Path( $path | Split-Path -Parent ) -ErrorAction 'SilentlyContinue';
    $encoding = switch( [System.IO.Path]::GetExtension( $path ) ) {
        { $_ -in '.ps1', '.xml' } { [System.Text.Encoding]::UTF8; }
        { $_ -in '.reg', '.vbs', '.js' } { [System.Text.UnicodeEncoding]::new( $false, $true ); }
        default { [System.Text.Encoding]::Default; }
    };
    $bytes = $encoding.GetPreamble() + $encoding.GetBytes( $file.InnerText.Trim() );
    [System.IO.File]::WriteAllBytes( $path, $bytes );
}
		</ExtractScript>
		<File path="C:\Windows\Setup\Scripts\RemovePackages.ps1">
$selectors = @(
	'Microsoft.Microsoft3DViewer';'Microsoft.BingSearch';'Microsoft.WindowsCalculator';
	'Microsoft.WindowsCamera';'Clipchamp.Clipchamp';'Microsoft.WindowsAlarms';
	'Microsoft.Copilot';'Microsoft.549981C3F5F10';'Microsoft.Windows.DevHome';
	'MicrosoftCorporationII.MicrosoftFamily';'Microsoft.WindowsFeedbackHub';
	'Microsoft.GetHelp';'Microsoft.Getstarted';'microsoft.windowscommunicationsapps';
	'Microsoft.WindowsMaps';'Microsoft.MixedReality.Portal';'Microsoft.BingNews';
	'Microsoft.MicrosoftOfficeHub';'Microsoft.Office.OneNote';'Microsoft.OutlookForWindows';
	'Microsoft.Paint';'Microsoft.MSPaint';'Microsoft.People';'Microsoft.PowerAutomateDesktop';
	'MicrosoftCorporationII.QuickAssist';'Microsoft.SkypeApp';'Microsoft.ScreenSketch';
	'Microsoft.MicrosoftSolitaireCollection';'Microsoft.MicrosoftStickyNotes';
	'MicrosoftTeams';'MSTeams';'Microsoft.Todos';'Microsoft.WindowsSoundRecorder';
	'Microsoft.Wallet';'Microsoft.BingWeather';'Microsoft.Xbox.TCUI';'Microsoft.XboxApp';
	'Microsoft.XboxGameOverlay';'Microsoft.XboxGamingOverlay';'Microsoft.XboxIdentityProvider';
	'Microsoft.XboxSpeechToTextOverlay';'Microsoft.GamingApp';'Microsoft.YourPhone';
	'Microsoft.ZuneMusic';'Microsoft.ZuneVideo';
);
$installed = Get-AppxProvisionedPackage -Online;
foreach( $selector in $selectors ) {
	$found = $installed | Where-Object { $_.DisplayName -eq $selector };
	if( $found ) { $found | Remove-AppxProvisionedPackage -AllUsers -Online -ErrorAction 'Continue'; }
}
		</File>
		<File path="C:\Windows\Setup\Scripts\RemoveCapabilities.ps1">
$selectors = @(
	'Print.Fax.Scan';'Language.Handwriting';'Browser.InternetExplorer';'MathRecognizer';
	'OneCoreUAP.OneSync';'OpenSSH.Client';'Microsoft.Windows.MSPaint';
	'App.Support.QuickAssist';'Microsoft.Windows.SnippingTool';'Language.Speech';
	'Language.TextToSpeech';'App.StepsRecorder';'Media.WindowsMediaPlayer';'Microsoft.Windows.WordPad';
);
$installed = Get-WindowsCapability -Online | Where-Object { $_.State -notin @('NotPresent','Removed') };
foreach( $selector in $selectors ) {
	$found = $installed | Where-Object { ($_.Name -split '~')[0] -eq $selector };
	if( $found ) { $found | Remove-WindowsCapability -Online -ErrorAction 'Continue'; }
}
		</File>
		<File path="C:\Windows\Setup\Scripts\RemoveFeatures.ps1">
$selectors = @('MediaPlayback';'Microsoft-RemoteDesktopConnection';'Recall';'Microsoft-SnippingTool';);
$installed = Get-WindowsOptionalFeature -Online | Where-Object { $_.State -notin @('Disabled','DisabledWithPayloadRemoved') };
foreach( $selector in $selectors ) {
	$found = $installed | Where-Object { $_.FeatureName -eq $selector };
	if( $found ) { $found | Disable-WindowsOptionalFeature -Online -Remove -NoRestart -ErrorAction 'Continue'; }
}
		</File>
		<File path="C:\Windows\Setup\Scripts\SetStartPins.ps1">
$json = '{"pinnedList":[]}';
if( [System.Environment]::OSVersion.Version.Build -lt 20000 ) { return; }
$key = 'Registry::HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Start';
New-Item -Path $key -ItemType 'Directory' -ErrorAction 'SilentlyContinue';
Set-ItemProperty -LiteralPath $key -Name 'ConfigureStartPins' -Value $json -Type 'String';
		</File>
		<File path="C:\Windows\Setup\Scripts\Specialize.ps1">
reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v BypassNRO /t REG_DWORD /d 1 /f;
Remove-Item -LiteralPath 'Registry::HKLM\Software\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\DevHomeUpdate' -Force -ErrorAction 'SilentlyContinue';
Remove-Item -LiteralPath 'C:\Users\Default\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk','C:\Windows\System32\OneDriveSetup.exe','C:\Windows\SysWOW64\OneDriveSetup.exe' -ErrorAction 'Continue';
Remove-Item -LiteralPath 'Registry::HKLM\Software\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\OutlookUpdate' -Force -ErrorAction 'SilentlyContinue';
reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Communications" /v ConfigureChatAutoInstall /t REG_DWORD /d 0 /f;
&amp; 'C:\Windows\Setup\Scripts\RemovePackages.ps1';
&amp; 'C:\Windows\Setup\Scripts\RemoveCapabilities.ps1';
&amp; 'C:\Windows\Setup\Scripts\RemoveFeatures.ps1';
net.exe accounts /maxpwage:UNLIMITED;
reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v AllowNewsAndInterests /t REG_DWORD /d 0 /f;
reg.exe add "HKLM\Software\Policies\Microsoft\Windows\CloudContent" /v "DisableWindowsConsumerFeatures" /t REG_DWORD /d 1 /f;
reg.exe add "HKLM\Software\Policies\Microsoft\Edge" /v HideFirstRunExperience /t REG_DWORD /d 1 /f;
&amp; 'C:\Windows\Setup\Scripts\SetStartPins.ps1';
		</File>
		<File path="C:\Windows\Setup\Scripts\DefaultUser.ps1">
reg.exe add "HKU\DefaultUser\Software\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f;
Remove-ItemProperty -LiteralPath 'Registry::HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'OneDriveSetup' -Force -ErrorAction 'Continue';
reg.exe add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f;
$names = @('ContentDeliveryAllowed';'FeatureManagementEnabled';'OEMPreInstalledAppsEnabled';'PreInstalledAppsEnabled';'PreInstalledAppsEverEnabled';'SilentInstalledAppsEnabled';'SoftLandingEnabled';'SubscribedContentEnabled';'SubscribedContent-310093Enabled';'SubscribedContent-338387Enabled';'SubscribedContent-338388Enabled';'SubscribedContent-338389Enabled';'SubscribedContent-338393Enabled';'SubscribedContent-353694Enabled';'SubscribedContent-353696Enabled';'SubscribedContent-353698Enabled';'SystemPaneSuggestionsEnabled';);
foreach( $name in $names ) { reg.exe add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v $name /t REG_DWORD /d 0 /f; }
reg.exe add "HKU\DefaultUser\Software\Policies\Microsoft\Windows\Explorer" /v DisableSearchBoxSuggestions /t REG_DWORD /d 1 /f;
reg.exe add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\RunOnce" /v "UnattendedSetup" /t REG_SZ /d "powershell.exe -WindowStyle \"Normal\" -ExecutionPolicy \"Unrestricted\" -NoProfile -File \"C:\Windows\Setup\Scripts\UserOnce.ps1\"" /f;
		</File>
		<File path="C:\Windows\Setup\Scripts\UserOnce.ps1">
Get-AppxPackage -Name 'Microsoft.Windows.Ai.Copilot.Provider' | Remove-AppxPackage;
Set-ItemProperty -LiteralPath 'Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Search' -Name 'SearchboxTaskbarMode' -Type 'DWord' -Value 1;
Set-ItemProperty -Path 'Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Start' -Name 'VisiblePlaces' -Value $( [convert]::FromBase64String('L7Nn496JVUO/zmHzexipN7wkihQM1olCoIBu2buiSIKGCHNSqlFDQp97J3ZYRlnU') ) -Type 'Binary';
Get-Process -Name 'explorer' -ErrorAction 'SilentlyContinue' | Where-Object { $_.SessionId -eq ( Get-Process -Id $PID ).SessionId; } | Stop-Process -Force;
		</File>
		<File path="C:\Windows\Setup\Scripts\FirstLogon.ps1">
Set-ItemProperty -LiteralPath 'Registry::HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name 'AutoLogonCount' -Type 'DWord' -Force -Value 0;
Remove-Item -LiteralPath @('C:\Windows\Panther\unattend.xml';'C:\Windows\Panther\unattend-original.xml';'C:\Windows\Setup\Scripts\Wifi.xml';) -Force -ErrorAction 'SilentlyContinue' -Verbose;
		</File>
	</Extensions>
</unattend>
'@

function New-AutounattendXML {
    param([string]$Username, [string]$Password, [string]$ComputerName, [string]$Edition)
    $productKey = switch ($Edition) {
        "home"       { "YTMG3-N6DKC-DKB77-7M9GH-8HVX7" }
        "enterprise" { "NPPR9-FWDCX-D2C8J-H872K-2YT43"  }
        default      { "VK7JG-NPHTM-C97JM-9MPGT-3V66T"  }
    }
    [xml]$doc = [System.Xml.XmlDocument]::new()
    $doc.LoadXml($Global:UnatemBase)
    $ns = [System.Xml.XmlNamespaceManager]::new($doc.NameTable)
    $ns.AddNamespace("u",   "urn:schemas-microsoft-com:unattend")
    $ns.AddNamespace("wcm", "http://schemas.microsoft.com/WMIConfig/2002/State")
    $n = $doc.SelectSingleNode("//u:settings[@pass='windowsPE']/u:component[@name='Microsoft-Windows-Setup']/u:UserData/u:ProductKey/u:Key", $ns)
    if ($n) { $n.InnerText = $productKey }
    $n = $doc.SelectSingleNode("//u:settings[@pass='specialize']/u:component[@name='Microsoft-Windows-Shell-Setup']/u:ComputerName", $ns)
    if ($n) { $n.InnerText = $ComputerName }
    $la = $doc.SelectSingleNode("//u:settings[@pass='oobeSystem']/u:component[@name='Microsoft-Windows-Shell-Setup']/u:UserAccounts/u:LocalAccounts/u:LocalAccount", $ns)
    if ($la) {
        $n = $la.SelectSingleNode("u:Name", $ns); if ($n) { $n.InnerText = $Username }
        $n = $la.SelectSingleNode("u:Password/u:Value", $ns); if ($n) { $n.InnerText = $Password }
    }
    $sh = $doc.SelectSingleNode("//u:settings[@pass='oobeSystem']/u:component[@name='Microsoft-Windows-Shell-Setup']", $ns)
    if ($sh) {
        $n = $sh.SelectSingleNode("u:AutoLogon/u:Username", $ns); if ($n) { $n.InnerText = $Username }
        $n = $sh.SelectSingleNode("u:AutoLogon/u:Password/u:Value", $ns); if ($n) { $n.InnerText = $Password }
    }
    $ms  = [System.IO.MemoryStream]::new()
    $xws = [System.Xml.XmlWriterSettings]::new()
    $xws.Indent = $true; $xws.IndentChars = "`t"
    $xws.Encoding = [System.Text.UTF8Encoding]::new($true)
    $xw = [System.Xml.XmlWriter]::Create($ms, $xws)
    $doc.WriteTo($xw); $xw.Flush(); $xw.Dispose()
    $result = [System.Text.UTF8Encoding]::new($true).GetString($ms.ToArray())
    $ms.Dispose(); return $result
}

# ---------------------------------------------
#  EVENTOS
# ---------------------------------------------
$BtnSelectISO.Add_Click({
    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.Title = "Seleccionar imagen ISO"; $dialog.Filter = "Imagenes ISO (*.iso)|*.iso"
    if ($dialog.ShowDialog()) {
        $Global:ISOPath = $dialog.FileName
        $TxtISOPath.Text = $Global:ISOPath
        $BtnMount.IsEnabled = $true
        $BtnAddFile.IsEnabled = $false; $BtnAddFolder.IsEnabled = $false; $BtnRecompile.IsEnabled = $false
        $LstFiles.Items.Clear(); Update-FileCount
        $Global:WorkDir = $null; $ProgressBar.Value = 0
        Write-UILog "ISO seleccionada: $Global:ISOPath" "OK"
        Set-Status "ISO seleccionada. Presione 'Montar ISO' para continuar." 5
    }
})

$BtnMount.Add_Click({
    if (-not $Global:ISOPath) { return }
    $BtnMount.IsEnabled = $false; $BtnSelectISO.IsEnabled = $false
    $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $rs.ApartmentState = "STA"; $rs.ThreadOptions = "ReuseThread"; $rs.Open()
    $rs.SessionStateProxy.SetVariable("ISOPath",    $Global:ISOPath)
    $rs.SessionStateProxy.SetVariable("WorkDirRef", ([ref]$Global:WorkDir))
    $rs.SessionStateProxy.SetVariable("Dispatcher", $Window.Dispatcher)
    $rs.SessionStateProxy.SetVariable("BtnMount",   $BtnMount)
    $rs.SessionStateProxy.SetVariable("BtnSelect",  $BtnSelectISO)
    $rs.SessionStateProxy.SetVariable("BtnFile",    $BtnAddFile)
    $rs.SessionStateProxy.SetVariable("BtnFolder",  $BtnAddFolder)
    $rs.SessionStateProxy.SetVariable("BtnBuild",   $BtnRecompile)
    $rs.SessionStateProxy.SetVariable("TxtStatus",  $TxtStatus)
    $rs.SessionStateProxy.SetVariable("TxtLog",     $TxtLog)
    $rs.SessionStateProxy.SetVariable("LogScroller",$LogScroller)
    $rs.SessionStateProxy.SetVariable("ProgBar",    $ProgressBar)
    $ps = [System.Management.Automation.PowerShell]::Create(); $ps.Runspace = $rs
    $null = $ps.AddScript({
        function UI-Log { param($msg,$lvl="INFO")
            $ts = Get-Date -Format "HH:mm:ss"
            $pfx = switch($lvl){"OK"{"[OK]"}"WARN"{"[WARN]"}"ERROR"{"[ERR]"}default{"-"}}
            $line = "[$ts] $pfx  $msg`n"
            $Dispatcher.Invoke([action]{$TxtLog.Text+=$line;$LogScroller.ScrollToEnd()})
        }
        function UI-Status { param($msg,$pct=-1)
            $Dispatcher.Invoke([action]{$TxtStatus.Text=$msg;if($pct-ge 0){$ProgBar.Value=$pct}})
        }
        $ok = $false
        try {
            UI-Status "Montando imagen ISO..." 15; UI-Log "Montando: $ISOPath"
            $mountResult = Mount-DiskImage -ImagePath $ISOPath -PassThru -ErrorAction Stop
            Start-Sleep -Milliseconds 2000
            $volume = $mountResult | Get-Volume -ErrorAction Stop
            if($null -eq $volume){ throw "No se detecto volumen." }
            $driveLetter = "$($volume.DriveLetter):"
            UI-Log "ISO montada en: $driveLetter" "OK"
            UI-Status "Extrayendo contenido..." 30
            $workDir = Join-Path $env:TEMP "ISOWorkshop_$(Get-Random)"
            New-Item -ItemType Directory -Path $workDir -Force | Out-Null
            $items = Get-ChildItem -Path "$driveLetter\" -Force
            $total = $items.Count; $i = 0
            foreach($item in $items){
                $i++; $pct = 30 + [int](($i/$total)*25)
                UI-Status "Extrayendo: $($item.Name)" $pct
                Copy-Item -Path $item.FullName -Destination $workDir -Recurse -Force -ErrorAction SilentlyContinue
            }
            Dismount-DiskImage -ImagePath $ISOPath -ErrorAction SilentlyContinue
            $WorkDirRef.Value = $workDir
            UI-Log "Extraccion completada." "OK"; UI-Status "Listo. Agregue archivos o genere autounattend.xml." 55
            $ok = $true
        } catch {
            UI-Log "ERROR: $_" "ERROR"; UI-Status "Error al procesar la ISO." 0
            try { Dismount-DiskImage -ImagePath $ISOPath -ErrorAction SilentlyContinue } catch {}
        }
        $Dispatcher.Invoke([action]{
            if($ok){ $BtnFile.IsEnabled=$true; $BtnFolder.IsEnabled=$true; $BtnBuild.IsEnabled=$true }
            else   { $BtnMount.IsEnabled=$true; $BtnSelect.IsEnabled=$true }
        })
    })
    $null = $ps.BeginInvoke()
})

$BtnAddFile.Add_Click({
    if (-not $Global:WorkDir) { return }
    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.Title = "Seleccionar archivo"; $dialog.Multiselect = $true
    $dialog.Filter = "Todos los archivos (*.*)|*.*"
    if ($dialog.ShowDialog()) {
        foreach ($file in $dialog.FileNames) {
            Copy-Item -Path $file -Destination (Join-Path $Global:WorkDir (Split-Path $file -Leaf)) -Force
            $LstFiles.Items.Add("[F]  $(Split-Path $file -Leaf)")
            Write-UILog "Archivo agregado: $(Split-Path $file -Leaf)" "OK"
        }
        Update-FileCount
    }
})

$BtnAddFolder.Add_Click({
    if (-not $Global:WorkDir) { return }
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Seleccionar carpeta a agregar"
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $folderName = Split-Path $dialog.SelectedPath -Leaf
        Copy-Item -Path $dialog.SelectedPath -Destination (Join-Path $Global:WorkDir $folderName) -Recurse -Force
        $LstFiles.Items.Add("[DIR]  $folderName")
        Write-UILog "Carpeta agregada: $folderName" "OK"; Update-FileCount
    }
})

$BtnClearList.Add_Click({
    $LstFiles.Items.Clear(); Update-FileCount
    if ($Global:WorkDir -and (Test-Path $Global:WorkDir)) {
        Get-ChildItem -Path $Global:WorkDir -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-UILog "Archivos de trabajo eliminados." "OK"
    }
    if (Test-Path $Global:XorrIsoBinDir) { Remove-Item -Path $Global:XorrIsoBinDir -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path $Global:XorrisoPath)   { Remove-Item -Path $Global:XorrisoPath   -Force -ErrorAction SilentlyContinue }
    Set-Status "Lista limpiada." 0; Write-UILog "Lista limpiada." "OK"
})

$BtnRecompile.Add_Click({
    if (-not $Global:WorkDir) {
        [System.Windows.MessageBox]::Show("Primero monte y extraiga una ISO.", "Aviso") | Out-Null; return
    }
    $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
    $saveDialog.Title = "Guardar nueva ISO"; $saveDialog.Filter = "Imagen ISO (*.iso)|*.iso"
    $saveDialog.FileName = "nueva_imagen.iso"
    if (-not $saveDialog.ShowDialog()) { return }
    $outputISO = $saveDialog.FileName

    $BtnRecompile.IsEnabled=$false; $BtnAddFile.IsEnabled=$false; $BtnAddFolder.IsEnabled=$false
    $BtnSelectISO.IsEnabled=$false; $BtnGenUnattend.IsEnabled=$false
    Open-BuildWindow

    $rs2 = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $rs2.ApartmentState = "STA"; $rs2.ThreadOptions = "ReuseThread"; $rs2.Open()
    $rs2.SessionStateProxy.SetVariable("WorkDir",         $Global:WorkDir)
    $rs2.SessionStateProxy.SetVariable("OutputISO",       $outputISO)
    $rs2.SessionStateProxy.SetVariable("OscdimgPath",     $Global:OscdimgPath)
    $rs2.SessionStateProxy.SetVariable("XorrisoPath",     $Global:XorrisoPath)
    $rs2.SessionStateProxy.SetVariable("XorrIsoBinDir",   $Global:XorrIsoBinDir)
    $rs2.SessionStateProxy.SetVariable("Dispatcher",      $Window.Dispatcher)
    $rs2.SessionStateProxy.SetVariable("BtnRecompile",    $BtnRecompile)
    $rs2.SessionStateProxy.SetVariable("BtnAddFile",      $BtnAddFile)
    $rs2.SessionStateProxy.SetVariable("BtnAddFolder",    $BtnAddFolder)
    $rs2.SessionStateProxy.SetVariable("BtnSelectISO",    $BtnSelectISO)
    $rs2.SessionStateProxy.SetVariable("BtnGenUnattend",  $BtnGenUnattend)
    $rs2.SessionStateProxy.SetVariable("BtnMount",        $BtnMount)
    $rs2.SessionStateProxy.SetVariable("TxtISOPath",      $TxtISOPath)
    $rs2.SessionStateProxy.SetVariable("LstFiles",        $LstFiles)
    $rs2.SessionStateProxy.SetVariable("TxtFileCount",    $TxtFileCount)
    $rs2.SessionStateProxy.SetVariable("TxtUnattendStatus",$TxtUnattendStatus)
    $rs2.SessionStateProxy.SetVariable("TxtStatus",       $TxtStatus)
    $rs2.SessionStateProxy.SetVariable("TxtLog",          $TxtLog)
    $rs2.SessionStateProxy.SetVariable("LogScroller",     $LogScroller)
    $rs2.SessionStateProxy.SetVariable("ProgBar",         $ProgressBar)
    $rs2.SessionStateProxy.SetVariable("BuildWin",        $Global:BuildWindow)
    $rs2.SessionStateProxy.SetVariable("BuildLogCtrl",    $Global:BuildLog)
    $rs2.SessionStateProxy.SetVariable("BuildProgCtrl",   $Global:BuildProg)
    $rs2.SessionStateProxy.SetVariable("BuildStatusCtrl", $Global:BuildStatus)

    $ps2 = [System.Management.Automation.PowerShell]::Create(); $ps2.Runspace = $rs2
    $null = $ps2.AddScript({
        function UI-Log2 { param($msg,$lvl="INFO")
            $ts  = Get-Date -Format "HH:mm:ss"
            $pfx = switch($lvl){"OK"{"[OK]"}"WARN"{"[WARN]"}"ERROR"{"[ERR]"}default{"-"}}
            $line= "[$ts] $pfx  $msg`n"
            $Dispatcher.Invoke([action]{$TxtLog.Text+=$line;$LogScroller.ScrollToEnd()})
            if ($null -ne $BuildWin) {
                $BuildWin.Dispatcher.Invoke([action]{
                    $BuildLogCtrl.Text += $line
                    $BuildWin.FindName("BuildLogScroller").ScrollToEnd()
                })
            }
        }
        function UI-Status2 { param($msg,$pct=-1)
            $Dispatcher.Invoke([action]{$TxtStatus.Text=$msg;if($pct-ge 0){$ProgBar.Value=$pct}})
            if ($null -ne $BuildWin -and $pct -ge 0) {
                $BuildWin.Dispatcher.Invoke([action]{
                    $BuildStatusCtrl.Text=$msg; $BuildProgCtrl.Value=$pct
                    $BuildWin.FindName("BuildPctTxt").Text="$pct%"
                })
            }
        }
        function Run-ISOTool { param([string]$Exe,[string]$ToolArgs)
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName=$Exe; $psi.Arguments=$ToolArgs
            $psi.RedirectStandardOutput=$true; $psi.RedirectStandardError=$true
            $psi.UseShellExecute=$false; $psi.CreateNoWindow=$true
            $psi.WorkingDirectory=[System.IO.Path]::GetDirectoryName($Exe)
            $proc = [System.Diagnostics.Process]::Start($psi)
            $errT = $proc.StandardError.ReadToEndAsync()
            $outT = $proc.StandardOutput.ReadToEndAsync()
            $proc.WaitForExit()
            foreach ($ln in (($outT.Result+"`n"+$errT.Result) -split "`n")) {
                $t=$ln.Trim(); if($t){UI-Log2 $t}
            }
            return @{Code=$proc.ExitCode; Err=$errT.Result}
        }
        function Test-XorrisoDLLs { param([string]$ExePath)
            $dir=[System.IO.Path]::GetDirectoryName($ExePath)
            foreach($dll in @("libburn-4.dll","libisoburn-1.dll","libisofs-6.dll")){
                if(-not(Test-Path(Join-Path $dir $dll))){return $false}
            }; return $true
        }
        function Copy-XorrIsoBinFolder { param([string]$SrcExePath)
            $srcDir=[System.IO.Path]::GetDirectoryName($SrcExePath)
            if(!(Test-Path $XorrIsoBinDir)){New-Item -ItemType Directory -Path $XorrIsoBinDir -Force|Out-Null}
            Get-ChildItem -Path $srcDir -Force | ForEach-Object {
                Copy-Item $_.FullName -Destination $XorrIsoBinDir -Recurse -Force -ErrorAction SilentlyContinue
            }
            $destExe=Join-Path $XorrIsoBinDir "xorriso.exe"
            if(Test-Path $destExe){return $destExe}; return $null
        }

        $ok=$false
        try {
            UI-Status2 "Buscando motor de compilacion..." 60
            $engineExe=$null; $engineTool=$null

            $adkCandidates=@(
                $OscdimgPath,
                "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe",
                "C:\Program Files\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
            )
            foreach($c in $adkCandidates){if(Test-Path $c){$engineExe=$c;$engineTool="oscdimg";break}}
            if($engineExe){UI-Log2 "Motor: oscdimg.exe -> $engineExe" "OK"}

            if(-not $engineExe){
                UI-Log2 "Intentando instalar ADK via winget..." "WARN"
                try{
                    $wg=Get-Command winget -ErrorAction SilentlyContinue
                    if($wg){
                        & winget install --id Microsoft.WindowsADK --silent --accept-source-agreements --accept-package-agreements 2>&1|Out-Null
                        foreach($c in $adkCandidates){if(Test-Path $c){$engineExe=$c;$engineTool="oscdimg";break}}
                        if($engineExe){UI-Log2 "oscdimg instalado via ADK." "OK"}
                    }
                }catch{UI-Log2 "winget ADK fallo: $_" "WARN"}
            }

            if(-not $engineExe){
                $xorBinExe=Join-Path $XorrIsoBinDir "xorriso.exe"
                if((Test-Path $xorBinExe)-and(Test-XorrisoDLLs $xorBinExe)){
                    $engineExe=$xorBinExe;$engineTool="xorriso";UI-Log2 "xorriso_bin listo." "OK"
                }elseif((Test-Path $XorrisoPath)-and(Test-XorrisoDLLs $XorrisoPath)){
                    $engineExe=$XorrisoPath;$engineTool="xorriso"
                }else{
                    if(Test-Path $XorrisoPath){Remove-Item $XorrisoPath -Force -ErrorAction SilentlyContinue}
                    if(Test-Path $XorrIsoBinDir){Remove-Item $XorrIsoBinDir -Recurse -Force -ErrorAction SilentlyContinue}
                    $xorFound=$false
                    try{
                        $wg=Get-Command winget -ErrorAction SilentlyContinue
                        if($wg){
                            UI-Log2 "winget install GNU.Xorriso..."
                            & winget install --id GNU.Xorriso --silent --accept-source-agreements --accept-package-agreements 2>&1|Out-Null
                            $roots=@("C:\Program Files\xorriso","C:\Program Files (x86)\xorriso","$env:LOCALAPPDATA\Microsoft\WinGet\Packages")
                            $foundExe=$null
                            foreach($root in $roots){
                                if(Test-Path $root){
                                    $foundExe=Get-ChildItem -Path $root -Filter "xorriso.exe" -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1
                                    if($foundExe){break}
                                }
                            }
                            if($foundExe){
                                $destExe=Copy-XorrIsoBinFolder $foundExe.FullName
                                if($destExe-and(Test-XorrisoDLLs $destExe)){
                                    $engineExe=$destExe;$engineTool="xorriso";$xorFound=$true
                                    UI-Log2 "xorriso + DLLs listos via winget." "OK"
                                }
                            }
                        }
                    }catch{UI-Log2 "winget xorriso fallo: $_" "WARN"}

                    if(-not $xorFound){
                        try{
                            UI-Log2 "Descargando xorriso desde GitHub..."
                            $zipPath=Join-Path $env:TEMP "xorriso_dl.zip"
                            $extractPath=Join-Path $env:TEMP "xorriso_extracted"
                            $ProgressPreference='SilentlyContinue'
                            Invoke-WebRequest -Uri "https://github.com/PeyTy/xorriso-exe-for-windows/archive/refs/heads/master.zip" -OutFile $zipPath -UseBasicParsing -TimeoutSec 120 -ErrorAction Stop
                            if((Test-Path $zipPath)-and(Get-Item $zipPath).Length -gt 10000){
                                if(Test-Path $extractPath){Remove-Item $extractPath -Recurse -Force}
                                Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
                                $xorExeGH=Get-ChildItem -Path $extractPath -Filter "xorriso.exe" -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1
                                if($xorExeGH){
                                    $destExe=Copy-XorrIsoBinFolder $xorExeGH.FullName
                                    if($destExe-and(Test-XorrisoDLLs $destExe)){
                                        $engineExe=$destExe;$engineTool="xorriso";$xorFound=$true
                                        UI-Log2 "xorriso GitHub + DLLs listos." "OK"
                                    }
                                }
                            }
                        }catch{UI-Log2 "Fallo GitHub: $_" "WARN"}
                        Remove-Item(Join-Path $env:TEMP "xorriso_dl.zip") -Force -ErrorAction SilentlyContinue
                        Remove-Item(Join-Path $env:TEMP "xorriso_extracted") -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    if(-not $xorFound){throw "No se pudo obtener motor de compilacion. Ejecuta: winget install Microsoft.WindowsADK"}
                }
            }

            UI-Status2 "Preparando compilacion..." 72
            $etfsboot=Join-Path $WorkDir "boot\etfsboot.com"
            $efisys=Join-Path $WorkDir "efi\microsoft\boot\efisys_noprompt.bin"
            if(-not(Test-Path $efisys)){$efisys=Join-Path $WorkDir "efi\microsoft\boot\efisys.bin"}
            $bootable=(Test-Path $etfsboot)-and(Test-Path $efisys)
            if($bootable){UI-Log2 "Imagen bootable (BIOS+UEFI)." "OK"}
            else{UI-Log2 "Sin archivos de arranque. ISO estandar." "WARN"}

            UI-Log2 "Motor: $engineTool -> $engineExe" "OK"
            UI-Status2 "Compilando ISO..." 75
            $bldRes=$null

            if($engineTool -eq "oscdimg"){
                if($bootable){$toolArgs="-m -o -u2 -udfver102 -bootdata:2#p0,e,b`"$etfsboot`"#pEF,e,b`"$efisys`" `"$WorkDir`" `"$OutputISO`""}
                else{$toolArgs="-m -o -u2 -udfver102 `"$WorkDir`" `"$OutputISO`""}
                $bldRes=Run-ISOTool $engineExe $toolArgs
                if($bldRes.Code -ne 0){
                    UI-Log2 "oscdimg fallo. Intentando xorriso..." "WARN"
                    $xf=Join-Path $XorrIsoBinDir "xorriso.exe"
                    if((Test-Path $xf)-and(Test-XorrisoDLLs $xf)){$engineExe=$xf;$engineTool="xorriso";$bldRes=$null}
                }
            }
            if($null -eq $bldRes -and $engineTool -eq "xorriso"){
                if($bootable){
                    $efisysRel=$efisys.Substring($WorkDir.Length).TrimStart('\').Replace('\','/')
                    $toolArgs="-as mkisofs -iso-level 3 -full-iso9660-filenames -udf -allow-limited-size -volid CCCOMA_X64FRE_ES-ES_DV9 -b boot/etfsboot.com -no-emul-boot -boot-load-size 8 -boot-info-table -eltorito-alt-boot -e `"$efisysRel`" -no-emul-boot -o `"$OutputISO`" `"$WorkDir`""
                }else{$toolArgs="-as mkisofs -iso-level 3 -full-iso9660-filenames -udf -allow-limited-size -volid CDROM -o `"$OutputISO`" `"$WorkDir`""}
                $bldRes=Run-ISOTool $engineExe $toolArgs
            }

            if($bldRes.Code -ne 0){throw "Compilacion fallida (codigo $($bldRes.Code)). Revisa el log."}
            UI-Log2 "ISO creada exitosamente." "OK"; UI-Status2 "ISO creada: $OutputISO" 100; $ok=$true

        }catch{
            UI-Log2 "ERROR: $_" "ERROR"; UI-Status2 "Error al crear la ISO." 0
            try{
                $diagPath=Join-Path([System.Environment]::GetFolderPath("Desktop")) "WinForge_ERROR_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
                @("=== WinForge v2.2 ERROR ===","Fecha: $(Get-Date)","","$_") | Out-File $diagPath -Encoding UTF8
                $Dispatcher.Invoke([action]{
                    [System.Windows.MessageBox]::Show("Diagnostico en el Escritorio:`n$diagPath","Error",[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error)|Out-Null
                })
            }catch{}
        }

        if($null -ne $BuildWin){
            $BuildWin.Dispatcher.Invoke([action]{
                $BuildWin.FindName("BuildCloseBtn").IsEnabled=$true
                if($ok){
                    $BuildStatusCtrl.Text="[OK] ISO creada exitosamente."
                    $BuildStatusCtrl.Foreground=[System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0x50,0xFA,0x7B)
                    $BuildProgCtrl.Value=100; $BuildWin.FindName("BuildPctTxt").Text="100%"
                }else{
                    $BuildStatusCtrl.Text="[ERROR] Fallo la compilacion."
                    $BuildStatusCtrl.Foreground=[System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0xF3,0x8B,0xA8)
                }
            })
        }
        $Dispatcher.Invoke([action]{
            if($ok){
                if(Test-Path $WorkDir){Remove-Item -Path $WorkDir -Recurse -Force -ErrorAction SilentlyContinue}
                [System.Windows.MessageBox]::Show("[OK] ISO creada:`n`n$OutputISO","Completado",[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Information)|Out-Null
                $TxtISOPath.Text="Ningun archivo seleccionado..."; $LstFiles.Items.Clear()
                $TxtFileCount.Text="0 elementos agregados"; $TxtUnattendStatus.Text="Sin autounattend.xml generado"
                $TxtUnattendStatus.Foreground=[System.Windows.Media.Brushes]::Gray
                $BtnMount.IsEnabled=$false; $BtnSelectISO.IsEnabled=$true; $BtnGenUnattend.IsEnabled=$true
                $BtnAddFile.IsEnabled=$false; $BtnAddFolder.IsEnabled=$false; $BtnRecompile.IsEnabled=$false
                $ProgBar.Value=0
            }else{
                $BtnRecompile.IsEnabled=$true; $BtnAddFile.IsEnabled=$true; $BtnAddFolder.IsEnabled=$true
                $BtnSelectISO.IsEnabled=$true; $BtnGenUnattend.IsEnabled=$true
            }
        })
    })
    $null = $ps2.BeginInvoke()
})

$BtnGenUnattend.Add_Click({
    $ReaderU=[System.Xml.XmlNodeReader]::new($XAML_Unattend)
    $WinU=[Windows.Markup.XamlReader]::Load($ReaderU); $WinU.Owner=$Window
    $UTxtUser=$WinU.FindName("TxtUser"); $UPwdPass=$WinU.FindName("PwdPass")
    $UTxtComputer=$WinU.FindName("TxtComputer"); $UCmbEdition=$WinU.FindName("CmbEdition")
    $WinU.FindName("BtnCancel").Add_Click({$WinU.DialogResult=$false;$WinU.Close()})
    $UTxtUser.Add_TextChanged({
        $s=$UTxtUser.Text -replace '[^a-zA-Z0-9\-]',''
        if($s.Length -gt 15){$s=$s.Substring(0,15)}
        $UTxtComputer.Text=$s.ToUpper()
    })
    $WinU.FindName("BtnGenerate").Add_Click({
        $user=$UTxtUser.Text.Trim(); $pass=$UPwdPass.Password
        $computer=$UTxtComputer.Text.Trim(); $edition=$UCmbEdition.SelectedItem.Tag
        if([string]::IsNullOrWhiteSpace($user)){
            [System.Windows.MessageBox]::Show("El nombre de usuario no puede estar vacio.","Validacion",[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Warning)|Out-Null; return
        }
        if([string]::IsNullOrWhiteSpace($computer)-or $computer -match '\s'){
            [System.Windows.MessageBox]::Show("Nombre del equipo invalido.","Validacion",[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Warning)|Out-Null; return
        }
        $WinU.DialogResult=$true
        $WinU.Tag=@{User=$user;Pass=$pass;Computer=$computer;Edition=$edition}
        $WinU.Close()
    })
    $result=$WinU.ShowDialog()
    if($result -eq $true -and $WinU.Tag){
        $cfg=$WinU.Tag
        Write-UILog "Generando autounattend.xml | Usuario: $($cfg.User) | Equipo: $($cfg.Computer)"
        $xmlContent=New-AutounattendXML -Username $cfg.User -Password $cfg.Pass -ComputerName $cfg.Computer -Edition $cfg.Edition
        if($Global:WorkDir -and (Test-Path $Global:WorkDir)){
            $destPath=Join-Path $Global:WorkDir "autounattend.xml"
            [System.IO.File]::WriteAllText($destPath,$xmlContent,[System.Text.UTF8Encoding]::new($true))
            Write-UILog "autounattend.xml guardado en raiz ISO: $destPath" "OK"
            $existing=$LstFiles.Items|Where-Object{$_ -like "*autounattend.xml*"}
            if($existing){$LstFiles.Items.Remove($existing)}
            $LstFiles.Items.Insert(0,"[XML]  autounattend.xml  [raiz ISO]"); Update-FileCount
            $TxtUnattendStatus.Text="[OK] autounattend.xml  |  Usuario: $($cfg.User)  |  Equipo: $($cfg.Computer)"
            $TxtUnattendStatus.Foreground=[System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0x50,0xFA,0x7B)
            Set-Status "autounattend.xml generado en raiz de la ISO." 100
        }else{
            $sd=New-Object Microsoft.Win32.SaveFileDialog
            $sd.Title="Guardar autounattend.xml"; $sd.Filter="XML (*.xml)|*.xml"; $sd.FileName="autounattend.xml"
            if($sd.ShowDialog()){
                [System.IO.File]::WriteAllText($sd.FileName,$xmlContent,[System.Text.UTF8Encoding]::new($true))
                Write-UILog "autounattend.xml guardado en: $($sd.FileName)" "OK"
                $TxtUnattendStatus.Text="[OK] Guardado en: $($sd.FileName)"
                $TxtUnattendStatus.Foreground=[System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0x50,0xFA,0x7B)
                [System.Windows.MessageBox]::Show("Guardado en:`n$($sd.FileName)","OK",[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Information)|Out-Null
            }
        }
    }
})

$Window.Add_Closing({
    if($Global:ISOPath){try{Dismount-DiskImage -ImagePath $Global:ISOPath -ErrorAction SilentlyContinue}catch{}}
    if($Global:WorkDir -and (Test-Path $Global:WorkDir)){Remove-Item -Path $Global:WorkDir -Recurse -Force -ErrorAction SilentlyContinue}
})

# ---------------------------------------------
#  ARRANQUE
# ---------------------------------------------
$isAdmin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if(-not $isAdmin){
    [System.Windows.MessageBox]::Show("Requiere privilegios de Administrador.","Permisos insuficientes",[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Warning)|Out-Null
    exit 1
}

Write-UILog "WinForge v2.2 iniciado." "OK"
Write-UILog "ScriptRoot : $Global:ScriptRoot" "OK"
Write-UILog "ToolsDir   : $Global:ToolsDir" "OK"

$adkExe="C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
if     (Test-Path $Global:OscdimgPath)   { Write-UILog "Motor listo: oscdimg en tools\" "OK" }
elseif (Test-Path $adkExe)               { Write-UILog "Motor listo: oscdimg ADK del sistema" "OK" }
elseif (Test-Path (Join-Path $Global:XorrIsoBinDir "xorriso.exe")) { Write-UILog "Motor listo: xorriso_bin" "OK" }
else   { Write-UILog "Motor no encontrado. Se instalara al compilar." "WARN"; Set-Status "Motor no encontrado. Se descargara al compilar." 0 }

$Window.ShowDialog() | Out-Null
