require 'metric_fu'

files = 'gpm.rb'

task default: [:test]

task :test do
  sh 'rspec'
end

task audit: [:check_style, :analyze_complexity, :detect_duplication, :question_design]

task :check_style do
  sh "rubocop #{files}"
  sh "cane #{files}"
end

task :analyze_complexity do
  sh "flog #{files}"
end

task :detect_duplication do
  sh "flay #{files}"
end

task :question_design do
  sh "roodi #{files}"
  sh "reek #{files}"
end

task :analyze_rework do
  sh "churn"
end
