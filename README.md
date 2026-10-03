# First Draft workshop

Everything happens in Claude Desktop's **Code** tab. You type a request, and Claude does the work. Plan on:

- **Setting up your laptop:** 20 to 60 minutes. It takes longer if your laptop needs to restart.
- **Signing in to your accounts:** about 15 minutes.
- **Building, launching and previewing your first app:** about 45 minutes.

## Part 1: Set up your laptop

1. Download this repo as a Zip folder.
2. Right-click the zip file you downloaded and choose "Extract All...".
   Extract it to your Documents folder or someplace you can easily find.
3. Open Claude Desktop, go to the Code tab, and open the extracted "workshop-kit" folder.
4. Start the setup. Type:
   ```text
   Set up my laptop for the workshop
   ```
   Claude installs the programs you need. If it asks you to restart, do so, then reopen the same folder in Claude
   Desktop and type `continue`.
5. When prompted, choose and enter a name for your project.

## Part 2: Sign in to your accounts

Have your workshop handout ready: First Draft asks for the workshop username and password from it.

6. Open a new session in Claude Desktop. Choose `WSL` &rarr; `Ubuntu-24.04` instead of `Local`.
   For "Choose folder", select the folder with the name of your project (`home` &rarr; `appdev` &rarr;
   `YOUR_PROJECT`).
7. Type `/workshop-signin` and press Enter. Claude opens each sign-in page in your browser and copies any code you
   need to your clipboard. Approve each one and tell Claude when you are done, until every account is signed in.

## Part 3: Build your first app

8. Download the social network design: **DESIGN_ZIP_LINK**. Leave the zip file in your Downloads folder.
9. Open a new session (`WSL` &rarr; `Ubuntu-24.04`, your project folder) and type:
   ```text
   /create-full-stack-app Build the social network in the design I just downloaded (the zip file in my Windows Downloads folder). Unzip it into this folder and read it first, then ask me only what the design doesn't settle. Include iPhone and Android apps.
   ```
10. Answer Claude's questions, and change anything you like: it's your app. Claude then shows you a summary of the
    plan, including anything First Draft can't build yet. When it looks right, approve it. Building takes about a
    minute.
11. Start the web app:
    ```text
    Start the web app.
    ```
    Open `http://localhost:3000` in your browser. If your app has sign-in, use the demo login Claude shows you.
12. Save your work to GitHub:
    ```text
    Commit the app and push it to a new private repository on my GitHub account. Give me the link.
    ```
    Pushing also starts GitHub building your iPhone and Android apps. That takes about five minutes, so carry on.
13. Put your app on the internet:
    ```text
    Deploy this app to Render's free plan with a Neon database. Give me the link when it's live.
    ```
    The first deploy takes a few minutes. Your live app starts with no data: the sample data is only on your laptop.
    Signing up on the live app needs email, which is set up later, so try sign-in features on your laptop.
14. Try your app on a phone, in your browser:
    ```text
    Show me the Android app in Revyl.
    ```
    Then:
    ```text
    Now show me the iPhone app.
    ```
    The link opens a phone in your browser. If Revyl asks you to sign in, use the same account as before.
15. Make it yours. For example:
    ```text
    Make the home page match the design's colors and fonts, then commit and push.
    ```
    Start with one screen: a whole redesign can take a long time. Your laptop's app updates right away, and Render
    updates the live app a minute or two after you push.

## Part 4: Start over with your own idea

16. Ask Claude for a new project folder:
    ```text
    Make a new project folder called MY_IDEA next to this one.
    ```
17. Open a new session (`WSL` &rarr; `Ubuntu-24.04`, the new folder) and describe your idea:
    ```text
    /create-full-stack-app A place for my book club to pick the next book and vote on meeting dates.
    ```
    Your sign-ins carry over, so you can go straight to building.

## If something goes wrong

- **The page stopped loading:** type `Restart the web app.`
- **Claude seems stuck:** press `Esc`, then type `continue`.
- **Claude asks you to approve something:** it checks before risky steps, such as deploying. Approve it if it is
  what you asked for.
- **The same step fails twice:** raise your hand, and leave the error on screen for the instructor.

## After the workshop

- To come back to a project, open a session with `WSL` &rarr; `Ubuntu-24.04` and choose its folder.
- Render's free plan sleeps when nobody visits, so the first visit afterwards takes about a minute.
- To remove an app from the internet, ask Claude: `Delete this app's Render service and its Neon project.`
