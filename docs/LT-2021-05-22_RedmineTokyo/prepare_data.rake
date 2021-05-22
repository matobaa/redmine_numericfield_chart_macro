=begin

How to use this script:

 DISABLE_DATABASE_ENVIRONMENT_CHECK=1 RAILS_ENV=production
REDMINE_LANG=en rails db:drop db:create db:migrate redmine:load_default_data
rails -R $(pwd) redmine:prepare_LT_data

=end


namespace :redmine do
    desc 'prepare data for a lightning talk'
    task :prepare_LT_data => :environment do

        class ::Time
            class << self
                alias :real_now :now
                def now
                    real_now - @fake_diff.to_i + 1
                end
                def fake(time)
                    @fake_diff = real_now - time
                    res = yield
                    @fake_diff = 0
                    res
                end
            end
        end

        user = User.find_by(:login => "admin")
        user&.must_change_passwd = false
        user&.save!
        user = User.find_by(:login => "jsmith")
        user&.must_change_passwd = false
        user&.save!

        status = IssueStatus.first_or_create!(:name => 'New')
        tracker = Tracker.first_or_create!(:name => 'Bug', :default_status => status)
        tracker.issue_statuses.append(status) if !tracker.issue_statuses.include?(status)
        author = User.first
        project = Project.find_or_create_by!(:identifier => 'demo', :name => 'demo')
        priority = Enumeration.find_or_create_by!(:name => 'Normal', :is_default => true, :type => 'IssuePriority')
        
        data = JSON.load(<<~EOJ)
        {
        "体温": {
            "お父さん": {"2021-05-15":"36.8"},
            "お母さん": {"2021-05-16":"", "2021-05-17":"36.3", "2021-05-19":"36.4", "2021-05-20":"36.2"},
            "お姉ちゃん": {"2021-05-19":"36.5", "2021-05-20":"36.6", "2021-05-21":"37.2", "2021-05-22":"37.5"},
            "お兄ちゃん": {"2021-05-15":"36.5", "2021-05-16":"36.7", "2021-05-22":"36.4"}
        },
        "ベンチプレス": {
            "福島さん": {"2020-11-22": "130", "2021-04-24": "132.5"},
            "早川さん": {"2020-11-22": "122.5", "2021-04-24": "110"},
            "寺村さん": {"2020-11-22": "107.5", "2021-04-24": "90"},
            "田中さん": {"2021-02-20": "55.0", "2021-04-24": "72.5"}
        },
        "残数": {
            "牛乳": {"2021-05-17": "4", "2021-05-19": "3", "2021-05-20": "2", "2021-05-21": "1"},
            "納豆": {"2021-05-20": "4", "2021-05-21": "3", "2021-05-22": "2"},
            "ちゅーる": {"2021-05-15": "6", "2021-05-16": "5", "2021-05-17": "3", "2021-05-18": "8"}
        },
        "ごきげん": {
            "奈良さん": {"2021-05-08": "4.2", "2021-05-15": "4.8"},
            "あきぴーさん": {"2021-05-15": "4", "2021-05-20": "3.7"},
            "門屋さん": {"2021-05-15": "5", "2021-05-19": "5"},
            "matobaa": {"2021-05-08": "5", "2021-05-15": "3.2", "2021-05-21": "2"}
        }
        }
        EOJ

        data.each do |cf_name, issues|
            cf = CustomField.find_or_create_by!(:name => cf_name, :type => 'IssueCustomField',
                :is_for_all => true, :is_filter => true, :field_format => 'float')
            tracker.custom_fields.append(cf) if !tracker.custom_fields.include?(cf)
            issues = issues.map do |subject, time_series|
                datetime, value = time_series.shift
                issue = Issue.new(:project => project, :tracker => tracker, :author => author, :subject => subject )
                issue.custom_values = [CustomValue.create!(:custom_field => cf, :value => value)] if !value.empty?
                Time.fake(Time.parse datetime) {issue.save!}
                old_value = value
                time_series.each do |datetime, value|
                    issue.clear_journal
                    journal = issue.init_journal(author)
                    p cf, issue
                    cv = CustomValue.find_or_create_by!(:custom_field => cf, :customized => issue)
                    cv.value = value
                    cv.save!
                    Time.fake(Time.parse datetime) do
                        journal.details.append(JournalDetail.create!(
                            :property => 'cf', :prop_key => cf.id, :old_value => old_value, :value => value))
                        journal.save!
                    end
                    old_value = value
                end
                issue
            end

            issue_id_list = issues.map{|issue| issue.id.to_s}.join(', ')
            wiki = Wiki.find_by!(:project => project)
            wikipage = WikiPage.find_or_create_by!(:title => cf_name, :wiki => wiki)
            wikipage.save_with_content(WikiContent.new(:text => "h1. #{cf_name}\n\n{{numericfield_chart(#{cf_name},#{issue_id_list})}}"))
            wiki.start_page = wikipage.title if !wiki.start_page?
            wiki.save!
        end

    end
end