# Average of the ACPI thermal zones, in Celsius, as a bare number.
# Called by the zebar bar every 10s through shellExec.
#
# Caveat worth remembering: on this machine the only zone (TZ10_0) reads ~17 C,
# which is a board/chassis sensor, not the CPU die. Real per-core temperature
# needs a kernel driver (LibreHardwareMonitor); this is the no-install option.
$ErrorActionPreference = 'Stop'
$zones = Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature
$avg = ($zones.CurrentTemperature | Measure-Object -Average).Average
[math]::Round($avg / 10 - 273.15, 1)
