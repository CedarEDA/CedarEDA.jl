# Launching CedarEDA on JuliaHub

The following documentation describes how to log into JuliaHub for the first time and launch CedarEDA.
The CedarEDA app is launched in the cloud running on a dedicated computer so there are a few extra steps to knowing how to manage the app.

## Login into JuliaHub

To launch CedarEDA first go to http://juliahub.com and click on the profile icon in the top-right corner to sign into your account.

```@raw html
<video src="https://help.juliahub.com/video/cedar-v0.4.5/juliahub_login.mp4" width="640" autoplay="true" loop="true" muted="true" title="Logging in to JuliaHub.com"></video>
```

## Launching the CedarEDA App
Once logged in you will see the CedarEDA app on the Home screen.
To start a CedarEDA job click the **Launch** button in the tile for CedarEDA.
This job will start booting up a new computer with CedarEDA ready to run.

```@raw html
<video src="https://help.juliahub.com/video/cedar-v0.4.5/juliahub_launch.mp4" width="640" autoplay="true" loop="true" muted="true" title="Launching CedarEDA"></video>
```

Note you can see your currently running jobs on the left side of the window under "Your Jobs".

## Connecting to CedarEDA
The first time CedarEDA is launched it will take about 7 minutes to start and successive launches will take about 1 minute.
Therefore there is a delay from launching CedarEDA to when it is ready to use.
Press the **Connect** button and a new browser tab will open and it will say "Connecting" until the CedarEDA app has finished loading.

```@raw html
<video src="https://help.juliahub.com/video/cedar-v0.4.5/juliahub_connect.mp4" width="640" autoplay="true" loop="true" muted="true" title="Connecting to CedarEDA"></video>
```

After connecting to CedarEDA there is a welcome screen to configure your environment.
There is also a "Welcome" tab with information with CedarEDA release notes.


## Running an Example Script

There are examples that can be run in the `examples (read-only)` folder.
It is recommended to start with the example in [`examples (read-only)/Filters/Butterworth/butterworth_transient.jl`](@ref butterworth-example).
To navigate to it click on the `examples (read-only)` folder in the **Explorer** pane on the left and then run the example by pressing `Shift-Enter` on each line to execute the line in the REPL at the bottom with the `julia>` prompt.

The lines with the `explore()` function will bring up a plot with interactive sliders to navigate the parametric sweep of values.
This interactive plot is demonstrated for transient and AC analysis, for more in-depth explanations see [Running Transient Analysis](@ref) and [Running DC Analysis](@ref).

```@raw html
<video src="https://help.juliahub.com/video/cedar-v0.4.5/juliahub_explore.mp4" width="640" autoplay="true" loop="true" muted="true" title="Exploring Transient Analysis"></video>
```

## Managing CedarEDA Jobs
The CedarEDA job will automatically timeout after a few hours, however the duration can be extended at any time and new jobs can have a longer time limit.
If you are within 30 minutes of the job stopping a notification will show giving the user the option to extend the time limit.
To extend the limit press the time remaining in the bottom statusbar:

```@raw html
<video src="https://help.juliahub.com/video/cedar-v0.4.5/juliahub_job_extension.mp4" width="640" autoplay="true" loop="true" muted="true" title="Extending the JuliaHub session"></video>
```

To change the default for a newly launched job go to your profile and change the default timeout on the **Preferences** page:

```@raw html
<video src="https://help.juliahub.com/video/cedar-v0.4.5/juliahub_job_defaults.mp4" width="640" autoplay="true" loop="true" muted="true" title="Default JuliaHub job settings"></video>
```

If the job timeout occurs the machine will be stopped but all files will kept for the next time a CedarEDA job is started.

To stop a job before the timeout occurs navigate to the JuliaHub **Home** page and press the stop link next to the job:

```@raw html
<video src="https://help.juliahub.com/video/cedar-v0.4.5/juliahub_job_stop.mp4" width="640" autoplay="true" loop="true" muted="true" title="Stopping a JuliaHub job"></video>
```

The state of the files will kept for next time a CedarEDA job is started.
