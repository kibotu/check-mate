# Launcher Icons Note

The project references launcher icons that need to be present in the `mipmap-*` directories. 

## Option 1: Use Android Studio's Image Asset Studio (Recommended)

1. In Android Studio, right-click on `app/src/main/res`
2. Select **New > Image Asset**
3. Choose **Launcher Icons (Adaptive and Legacy)**
4. Configure your icon (you can use built-in clipart or upload your own image)
5. Click **Next** and then **Finish**

This will automatically generate all required launcher icons in the correct densities.

## Option 2: Use Default Android Icons

If you just want to run the app without custom icons, Android Studio will use default placeholder icons automatically. The app will build and run fine.

## Required Icon Files (if manually creating)

If you want to manually add icons, you need these files:

```
app/src/main/res/
├── mipmap-hdpi/
│   ├── ic_launcher.png
│   └── ic_launcher_foreground.png
├── mipmap-mdpi/
│   ├── ic_launcher.png
│   └── ic_launcher_foreground.png
├── mipmap-xhdpi/
│   ├── ic_launcher.png
│   └── ic_launcher_foreground.png
├── mipmap-xxhdpi/
│   ├── ic_launcher.png
│   └── ic_launcher_foreground.png
└── mipmap-xxxhdpi/
    ├── ic_launcher.png
    └── ic_launcher_foreground.png
```

The app will work without these - Android will use default icons.

