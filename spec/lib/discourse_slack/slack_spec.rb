require 'rails_helper'

RSpec.describe DiscourseSlack::Slack do
  let(:post) { Fabricate(:post) }

  describe '.excerpt' do
    describe 'when post contains emoijs' do
      before do
        post.update!(raw: ':slight_smile: This is a test')
      end

      it 'should return the right excerpt' do
        expect(described_class.excerpt(post)).to eq('🙂 This is a test')
      end
    end

    describe 'when post contains onebox' do
      it 'should return the right excerpt' do
        post.update!(cooked: <<~COOKED
        <aside class=\"onebox whitelistedgeneric\">
          <header class=\"source\">
            <a href=\"http://somesource.com\">
              meta.discourse.org
            </a>
          </header>

          <article class=\"onebox-body\">
            <img src=\"http://somesource.com\" width=\"\" height=\"\" class=\"thumbnail\">

            <h3>
              <a href=\"http://somesource.com\">
                Some text
              </a>
            </h3>

            <p>
              some text
            </p>

          </article>

          <div class=\"onebox-metadata\">\n    \n    \n</div>
          <div style=\"clear: both\"></div>
        </aside>
        COOKED
        )

        expect(described_class.excerpt(post))
          .to eq('<http://somesource.com|meta.discourse.org>')
      end
    end
  end
end
