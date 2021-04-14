redmine_numericfield_chart_macro
================================

A wiki macro for Redmine ITS; to display a chart of numeric custom field.

# description

(ATDK)

# Installation

1. Go to your Redmine installation's plugins/ directory.
2. `git clone https://github.com/matobaa/redmine_numericfield_chart_macro`
3. `make` to retrieve required javascript library.
3. Restart Redmine.

# Uninstallation
1. Go to your Redmine installation's plugins/ directory.
2. `rails redmine:plugins:migrate name=redmine_numericfield_chart_macro version=0`
3. `rm -r redmine_numericfield_chart_macro`
