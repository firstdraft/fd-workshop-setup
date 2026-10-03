# README


1. Download this repo as a Zip folder.
2. Right-click the zip file you downloaded and choose "Extract All...".
   Extract it to your Documents folder or someplace you can easily find.  
3. Open Claude Desktop, go to the Code tab, and open the extracted
   "workshop-kit" folder.
4. Start the setup. Type:
   ```txt
   Set up my laptop for the workshop
   ```
5. Claude will install the required programs for you.
6. When prompted, choose and enter a name for your project.
7. Next, Claude will guide you through signing in to the required accounts.
   If you are on Windows: you will need to open a new session in Claude Desktop. Choose `WSL` &rarr; `Ubuntu-24.04` instead of `Local`.
   For "Choose folder", select the folder with the name of your project (it's under `home/` &rarr; `appdev/` &rarr; `MY_APP_NAME/`)
   Type `/workshop-signin` and hit Enter. Claude will open the browser for you at the authorization page for each service
   and copy any required codes to your clipboard so you can easily paste them.
   Continue with this until all services have been authorized.
8. Open a new session in the same folder.
   Enter a description of your app idea:
   ```text
   /create-full-stack-app

   Build a Reading List.
   Each book has a required title and author, an optional note, and a finished checkbox that starts unchecked.
   Let anyone list, view, add, edit, and delete books.
   Include three sample books.
   Generate both iPhone and Android clients.
   This is a public demonstration with disposable data and no accounts.
   Use First Draft's service, put the compiled app in this local folder, and run it locally.
   Show me the Plan, warnings, and support gaps before compiling.
   Do not publish to GitHub or deploy.
   ```
9. Answer any questions and clarify any features.
10. Approve when you are ready and Claude will generate the code for your app.
11. Save a checkpoint.
    ```text
    Initialize a local Git repository and make a commit of the generated codebase. Keep API tokens, private CLI state, and local environment files out of Git.
    ```
12. Connect to GitHub.
    ```text
    Create a repository on my personal GitHub account for this project and push my commits to it.
    Print out the URL of the GitHub repository when you finish.
    ```
13. Start the Web app.
    ```bash
    Start the web app.
    ```
    Open `http://localhost:3000` in your browser and visit your app!
14. Deploy to Render.
    ```txt
    Deploy this Rails app to Render using the Render CLI.
    The web service should use the free plan and auto deploy on Git commit.
    The web server should create and use a database from Neon.
    Once the deploy has finished tell me the URL of the app.
    ```
    Once the deploy finishes, you should see a permanent URL to your app running on Render servers.
    Open it in your browser and click around!
15. Preview the Android app with Revyl.
    ```txt
    Preview the Android app with Revyl using the local web app.
    Give me the preview link so I can open it in my browser.
    ```
    When you are done:
    ```text
    Stop the Revyl Android preview
    ```
16. Preview the iOS app with Revyl.
    ```txt
    Preview the iOS app with Revyl using the local web app.
    Give me the preview link so I can open it in my browser.
    ```
    When you are done:
    ```text
    Stop the Revyl iOS preview
    ```
17. Iterate with your agent.
    ```txt
    Update the background of the home page with a geometric style background pattern.
    Save these changes and update GitHub and the Render app.
    ```
