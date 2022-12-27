$PCTypes = 1..4+6,7,13
$LaptopTypes = 8..10+14,31
$HardwareType = 31
if ($HardwareType -in $PCTypes) {
    echo "PC"
}
elseif ($HardwareType -in $LaptopTypes) {
    echo "Laptop"
}
else {
    echo "Couldn't guess the type of $HardwareType"
}
