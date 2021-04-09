all: assets/javascripts/chart.js assets/javascripts/chartjs-adapter-moment.js assets/javascripts/moment.js
	# bundle install

assets/javascripts/chart.js: 
	-mkdir -p assets/javascripts
	wget https://cdn.jsdelivr.net/npm/chart.js@3.0.2/dist/chart.js -P assets/javascripts

assets/javascripts/chartjs-adapter-moment.js:
	-mkdir -p assets/javascripts
	wget https://cdn.jsdelivr.net/npm/chartjs-adapter-moment@1.0.0/dist/chartjs-adapter-moment.js -P assets/javascripts

assets/javascripts/moment.js:
	-mkdir -p assets/javascripts
	wget https://cdn.jsdelivr.net/npm/moment@2.29.1/moment.js -P assets/javascripts
