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
  version '0.1.0'
  url 'https://github.com/matobaa/redmine_numericfield_chart_macro'
  author_url 'http://www.github.com/matobaa'
end

Redmine::WikiFormatting::Macros.register do
  desc <<~DESC
    Render a chart of custom values of the specified issue

    {{numericfield_chart(cf_name, 2, 3, 5)}}    -- values of custom_field "cf_name" of issue #2, #3, #5
  DESC
  macro :numericfield_chart do |obj, args|
    cf_name = args.shift
    if CustomField.find_by(:name => cf_name).nil?
      raise "numericfield_chart: requires exactly correct custom field name on 1st argument."
    end

    if(args.empty?)
      raise "numericfield_chart: no issue numbers. it requires issue numbers follows with a custom field name."
    end
    issues = args.map &:to_i
    issues.delete(0)

    details =
      JournalDetail
      .where(
        :property => :cf,
        :prop_key => CustomField.find_by(:name => cf_name))
      .joins(:journal)
      .select("created_on, journalized_id as id, old_value, value")
      .where("journals.journalized_id" => issues)
      .order("journalized_id, created_on")
      .as_json

    initials =
      CustomValue
      .joins('join issues on issues.id = customized_id')
      .select("issues.id, issues.subject, created_on, value")
      .where("issues.id" => issues, :custom_field_id => CustomField.find_by(:name => cf_name))
      .order("issues.id")
      .as_json

    dataset =
      (initials+details)
      .group_by {|e| e["id"] }
      .map do |id, journals|
        subject = journals[0]["subject"]
        journals[0]["value"] = journals[1]["old_value"] if journals.length > 1
        journals.delete_if {|journal| journal["value"].nil? || journal["value"].empty?}
        [subject, journals]
      end
      .to_h
      .map do |subject, journals|
        {:label => subject, :data => journals.map {|j| {:x => j["created_on"], :y => j["value"]}}}
      end

    content_tag :div do
      concat javascript_include_tag('chart', :plugin => 'redmine_numericfield_chart_macro')
      concat javascript_include_tag('moment', :plugin => 'redmine_numericfield_chart_macro')
      concat javascript_include_tag('chartjs-adapter-moment', :plugin => 'redmine_numericfield_chart_macro')
      concat tag.canvas :id => 'numericfield_chart'
      concat tag.script <<~JAVASCRIPT.html_safe

        var ctx = document.getElementById('numericfield_chart');
        const colorScheme = [
          "#25CCF7","#FD7272","#54a0ff","#00d2d3",
          "#1abc9c","#2ecc71","#3498db","#9b59b6","#34495e",
          "#16a085","#27ae60","#2980b9","#8e44ad","#2c3e50",
          "#f1c40f","#e67e22","#e74c3c","#ecf0f1","#95a5a6",
          "#f39c12","#d35400","#c0392b","#bdc3c7","#7f8c8d",
          "#55efc4","#81ecec","#74b9ff","#a29bfe","#dfe6e9",
          "#00b894","#00cec9","#0984e3","#6c5ce7","#ffeaa7",
          "#fab1a0","#ff7675","#fd79a8","#fdcb6e","#e17055",
          "#d63031","#feca57","#5f27cd","#54a0ff","#01a3a4"
        ]
        var datasets = #{dataset.to_json}
        datasets.forEach((dataset,i) => dataset.backgroundColor = colorScheme[i%colorScheme.length])

        var myChart = new Chart(ctx, {
          type: 'scatter',
          data: { datasets },
          options: { scales: { x: { type: 'time' } }, showLine: true,
          responsive: true, maintainAspectRatio: true }
        });
      JAVASCRIPT
    end
  end
end
