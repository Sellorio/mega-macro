# Mega Macro (a World of Warcraft AddOn)

![Screenshot 1](https://raw.githubusercontent.com/Sellorio/mega-macro/master/Screenshot1.png)

**IMPORTANT:** Before you use this AddOn, make sure you read the `before you use` section!

## Features

Use the `/m` command to begin your new macro experience!

Once macro import is complete, `/m` will only show the new macro UI.

### More macro slots!

This AddOn seamlessly provides you with a massive increase to macro slots over the native amounts of
120 global and 18 per-character slots that the Blizzard UI provides. How does it do this? By segmenting
the 138 total macro slots into 5 categories and hot-switching macros based on your Class and Specialization.

The breakdown of macro slots is as follows:

1. 60 global macros
2. 30 per-class macros
3. 30 per-specialization macros
4. 8 per-character macros
5. 10 per-character per-specialization macros

That's an amazing 30 slots you can use to setup your macros for each specialization where previously you
would be forced to fit all your class macros for all specializations into a max of 18 slots!!

I'm not just trying to be a sales person here - I've wanted this feature for ages. Especially as a Druid
main!

### Shared macros across characters

Building on the last feature, the per-class and per-specialization macros are not character specific so
you don't need to copy your macros around manually if you have more than one character of a particular
class.

### Improved macro icon/tooltip evaluation

This is the other big feature added by this AddOn. By default the Blizzard UI picks your icon based on
`#showtooltip` or uses the icon of the spell that will be cast (and doesn't use it's tooltip). Mega Macro
does the following:

1. `#showtooltip` as source for icon and tooltip always when present
2. The spell/item/toy that will be cast will have its icon _and tooltip_ used
3. You can make the icon setting be the fallback icon to display
4. If no spell/item/toy/icon will be used, picks the first spell/item/toy in the macro and shows that

Number 3 is the kicker here. This means if you are a healer and have heal-safe macros like this one:

```
/cast [help, no dead] Heal
```

Then you don't need to prefix your macro code with `#showtooltip Heal` - the AddOn handles that for you! This
cuts down on some of the redundant manual work required to write a macro and reduces the amount of macro code
capacity you have to use on non-functional code.

As a bonus to the above improvement, cast-sequence commands will not only effortlessly display the correct icon,
you'll also get the tooltip for the sequence abilities - impossible in the current macro implementation.

### Bigger macros!

Write macros up to 1023 characters long. No more having to minify your macro code making it harder to
read. Spread out those casts, have them on separate lines for more readability and/or add comments. You can do
so much more with four times the code capacity!

### Ids are preserved

Your action bars will not break. Your macros defined in the Mega Macro UI will use the same macro slot
for their entire lifetime so you don't have to worry about your action bars breaking when switching
characters and specializations.

### Improved macro UI

The Mega Macro UI replicates the native macro UI down to every last detail **except for the following**
**improvements**:

* Searchable icon list
* Wider, making better use of screen space
* Higher, expanding the macro text box so you'll rarely have to scroll to view your code
* Buttons are contextually disabled
* "Change Name/Icon" changed to "Rename"
* Icons in macros list and selected macro are updated dynamically based on macro conditionals
* Icons in macros list and selected macro trigger tooltips

## Before you use

This AddOn will destroy your existing macros once they have been imported. If the import fails, the AddOn
won't do anything to your macros until it is successful.

Once successfully imported, if you remove the AddOn you will have 138 stub macros and your old macros will
be gone.

To avoid this, follow the instructions below.

### When you install the AddOn

**Before you start the game**, you'll want to back up your macros. To do this:

1. Windows + R (open the run dialog)
2. Enter the following command:

```
robocopy "C:\Program Files (x86)\World of Warcraft\_retail_\WTF\Account" %USERPROFILE%\Games\wow-macro-backup macros-cache.txt /s
```

3. click OK

### When you want to remove the AddOn

Do the following steps **after exiting the game**.

1. Windows + R (open the run dialog)
2. Enter the following command:

```
xcopy /e /i /y %USERPROFILE%\Games\wow-macro-backup "C:\Program Files (x86)\World of Warcraft\_retail_\WTF\Account"
```

3. click OK

## Special Thanks

Special thanks to `aurelion314` (`Cubelicious` in-game) and `Dannez83` for contributing many hours to update this addon for Dragonflight!