1. Go to `https://<your-team>.slack.com/apps/new/A0F82E8CA-slash-commands` to create a new outgoing command.\*

2. Enter the name of the command (eg `/discourse`) and click "Add Slash Command Integration":

    ![New Slash Command](https://cloud.githubusercontent.com/assets/1386403/16739197/f925f9f6-4766-11e6-92a7-8ea7897e7150.png)  
    
    If you have more than one Discourse instance, you need to add add a different slash command for each instance.

3. In the "URL" field, enter the URL that the slash command will post to: `<your-discourse-url>/slack/command`

4. Copy your API token from the "Token" field:

    ![Add slash command](https://cloud.githubusercontent.com/assets/1386403/16739199/f92d42ec-4766-11e6-9ea5-131d5625db2e.png)

5. Go to your Discourse settings page, found at `<your-discourse-url>/admin/site_settings/category/plugins`. In the left-hand menu, scroll down and click "Plugins".

6. In the "slack incoming webhook token" field, paste your API token:

    ![Settings Page](https://cloud.githubusercontent.com/assets/1386403/16739198/f92c6b60-4766-11e6-99b2-877a370f67b5.png)  
    You can optionally set the user that Slack will use, and change the size of the excerpts being posted.
    
7. In Slack, go to the channel you want to post notifications to, and enter the slash command you set up in step 2. 

  The bot will show you the options for subscribing to notifications:
  
  ![Slack options](https://cloud.githubusercontent.com/assets/3482051/17478266/84614b40-5d62-11e6-9a5c-9aae615ce7db.png)
