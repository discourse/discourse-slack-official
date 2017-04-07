module Jobs
  class SyncSlack < Jobs::Scheduled
  	every 15.minutes

    def execute(args)
      DiscourseSlack::Slack.sync
    end
  end
end
