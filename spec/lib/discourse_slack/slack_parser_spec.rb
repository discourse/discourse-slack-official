require 'rails_helper'

RSpec.describe DiscourseSlack::SlackParser do
  describe '.get_excerpt' do
    describe 'when content contains a link with an incomplete URL' do
      it 'should return the right excerpt' do
        expect(described_class.get_excerpt("test <a href='//localhost:3000/some/path'></a>", 1000))
          .to eq("test <http://localhost:3000/some/path|>")

        SiteSetting.force_https = true

        expect(described_class.get_excerpt("test <a href='//localhost:3000/some/path'></a>", 1000))
          .to eq("test <https://localhost:3000/some/path|>")
      end
    end
  end
end
