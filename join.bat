@echo off
cd /d "%~dp0"
echo Joining the parts into pearyos-1.0-amd64.iso - this takes a minute...
copy /b pearyos-1.0-amd64.iso.part-001+pearyos-1.0-amd64.iso.part-002+pearyos-1.0-amd64.iso.part-003+pearyos-1.0-amd64.iso.part-004+pearyos-1.0-amd64.iso.part-005+pearyos-1.0-amd64.iso.part-006+pearyos-1.0-amd64.iso.part-007+pearyos-1.0-amd64.iso.part-008+pearyos-1.0-amd64.iso.part-009+pearyos-1.0-amd64.iso.part-010+pearyos-1.0-amd64.iso.part-011+pearyos-1.0-amd64.iso.part-012+pearyos-1.0-amd64.iso.part-013+pearyos-1.0-amd64.iso.part-014+pearyos-1.0-amd64.iso.part-015+pearyos-1.0-amd64.iso.part-016+pearyos-1.0-amd64.iso.part-017+pearyos-1.0-amd64.iso.part-018+pearyos-1.0-amd64.iso.part-019+pearyos-1.0-amd64.iso.part-020+pearyos-1.0-amd64.iso.part-021+pearyos-1.0-amd64.iso.part-022+pearyos-1.0-amd64.iso.part-023+pearyos-1.0-amd64.iso.part-024+pearyos-1.0-amd64.iso.part-025+pearyos-1.0-amd64.iso.part-026+pearyos-1.0-amd64.iso.part-027+pearyos-1.0-amd64.iso.part-028+pearyos-1.0-amd64.iso.part-029 pearyos-1.0-amd64.iso
echo.
echo SHA-256 of the joined file - it must match the expected value below:
certutil -hashfile pearyos-1.0-amd64.iso SHA256
echo.
echo expected: c41bf5ce6076edfdf7c9a92bc6c3de72dad9ffd4b1a53440a380b181b7b76da1
pause
