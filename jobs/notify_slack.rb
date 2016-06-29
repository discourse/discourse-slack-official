module Jobs
  class NotifySlack < Jobs::Base
    def execute(args)
      ::DiscourseSlack::Slack.notify(args[:post])
    end
  end
end