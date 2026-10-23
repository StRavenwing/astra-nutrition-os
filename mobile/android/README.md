# Android build

This project uses Android Gradle Plugin `8.6.1`, Gradle `8.9`, Kotlin `2.0.21`, and Java 17.

Open `mobile/android` as the Gradle project. Do not import the repository root or the `mobile` directory as an Eclipse/Buildship project.

In Android Studio, set **Settings → Build, Execution, Deployment → Build Tools → Gradle → Gradle JDK** to the bundled JDK 17 (or another JDK 17+). The system Java 8 installation is not compatible with AGP 8.x.

Build from PowerShell:

```powershell
cd mobile/android
./gradlew.bat :app:assembleDebug
```

If VS Code/Buildship reports that the `android` project description is out of sync, close the project, remove the generated Eclipse/Buildship metadata for that imported project (`.project`/`.classpath` outside this repository), then reopen `mobile/android` as a Gradle project and refresh the Gradle model. Those files are IDE metadata and are not part of this repository.
