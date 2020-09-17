CALL .\depublish.bat
mkdir "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\MegaMacro"
xcopy /e /i /exclude:..\.publishignore .. "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\MegaMacro"