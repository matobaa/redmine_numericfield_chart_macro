=begin

How to use this script:

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

        status = IssueStatus.first_or_create!(:name => 'New')
        tracker = Tracker.first_or_create!(:name => 'Bug', :default_status => status)
        tracker.issue_statuses.append(status) if !tracker.issue_statuses.include?(status)
        author = User.first
        project = Project.find_or_create_by!(:identifier => 'demo', :name => 'demo')
        priority = Enumeration.find_or_create_by!(:name => 'Normal', :is_default => true, :type => 'IssuePriority')
        
        data = JSON.load(<<~EOJ)
        {"体温": {
            "お父さん": {"2021-05-08":"36.8"},
            "お母さん": {"2021-05-09":"", "2021-05-10":"36.3", "2021-05-12":"36.4", "2021-05-13":"36.2"},
            "お姉ちゃん": {"2021-05-12":"36.5", "2021-05-13":"36.6", "2021-05-14":"37.2", "2021-05-15":"37.5"},
            "お兄ちゃん": {"2021-05-08":"36.5", "2021-05-09":"36.7", "2021-05-15":"36.4"}
        }
        }
        EOJ

        data.each do |cf_name, issues|
            cf = CustomField.find_or_create_by!(:name => cf_name, :type => 'IssueCustomField',
                :is_for_all => true, :field_format => 'float')
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
                    cv = CustomValue.find_by(:custom_field => cf, :customized => issue)
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
            wikipage = WikiPage.find_or_create_by!(:title => 'Demo', :wiki => wiki)
            wikipage.save_with_content(WikiContent.new(:text => "{{numericfield_chart(#{cf_name},#{issue_id_list})}}"))
            wiki.start_page = wikipage.title if !wiki.start_page?
        end

    end
end