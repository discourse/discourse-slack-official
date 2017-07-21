require 'rails_helper'

RSpec.describe DiscourseSlack::SlackMessageFormatter do
  describe '.format' do
    context 'links' do
      it 'should return the right message' do
        expect(described_class.format("<a href='http://somepath.com'>test</a>")).to eq('<http://somepath.com|test>')
      end

      describe 'when text contains a link with an incomplete URL' do
        it 'should return the right message' do
          expect(described_class.format("test <a href='//localhost:3000/some/path'></a>")).to eq("test <http://localhost:3000/some/path|>")

          SiteSetting.force_https = true

          expect(described_class.format("test <a href='//localhost:3000/some/path'></a>")).to eq("test <https://localhost:3000/some/path|>")
        end
      end

      it "should not raise an error with unparseable urls" do
        expect(described_class.format("<a>test</a>")).to eq("<test.localhost|test>")
      end

      it "should not raise an error with non http/s scheme" do
        expect(described_class.format("<a href=\"mailto:foo@bar.com\">:mail:</a>")).to eq("<mailto:foo@bar.com|:mail:>")
        expect(described_class.format("<a href=\"mobile:123456789\">:phone:</a>")).to eq("<mobile:123456789|:phone:>")
      end

    end
  end
end
