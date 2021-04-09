# frozen_string_literal: true

# Copyright (C) 2021 by Akihiro MATOBA <matobaa@gmail.com>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>

Redmine::Plugin.register :redmine_numericfield_chart_macro do
  name 'Redmine Numericfield Chart macro'
  author 'Akihiro MATOBA'
  description 'displays a chart of numeric custom field with chart.js'
  version '0.0.1'
  url 'https://github.com/matobaa/redmine_numericfield_chart_macro'
  author_url 'http://www.github.com/matobaa'
end

Redmine::WikiFormatting::Macros.register do
  macro :numericfield_chart do |obj, args|
    word = args.first

    cf_name = 'Float field'
    issues = [3, 4, 15]

    details =
      JournalDetail.where(
        :property => :cf,
        :prop_key => CustomField.find_by(:name => cf_name)).
      joins(:journal).
      select("created_on, journalized_id as id, old_value, value").
      where("journals.journalized_id" => issues).
      order("journalized_id, created_on").
      as_json

    initials =
      CustomValue.joins('join issues on issues.id = customized_id').
      select("issues.id, created_on, value").
      where("issues.id" => issues, :custom_field_id => CustomField.find_by(:name => cf_name)).
      as_json

    dataset =
      (initials+details).
      group_by {|e| e["id"] }.
      each do |id, journals|
        journals[0]["value"] = journals[1]["old_value"] if journals.length > 1
        journals.delete_if {|journal| journal["value"].nil?}
        journals.each do |journal|
          journal.delete("old_value")
          journal.delete("id")
        end
      end

    dataset = dataset.
      deep_transform_keys {|key| {"value" => "y", "created_on" => "x"}[key] || key}.
      map {|k, v| {:label => k, :data => v}}

    content_tag :div do
      concat javascript_include_tag('chart', :plugin => 'redmine_numeric_field_chart_macro')
      concat javascript_include_tag('moment', :plugin => 'redmine_numeric_field_chart_macro')
      concat javascript_include_tag('chartjs-adapter-moment', :plugin => 'redmine_numeric_field_chart_macro')
      concat tag.canvas :id => 'numericfield_chart'
      concat tag.script <<~JAVASCRIPT.html_safe

        var ctx = document.getElementById('numericfield_chart');
          var myChart = new Chart(ctx, {
            type: 'scatter',
            data: {
              datasets: #{dataset.to_json}
            },
            options: { scales: { x: { type: 'time' } }, showLine: true, 
            responsive: false, maintainAspectRatio: false }
          });
      JAVASCRIPT
    end
  end
end
