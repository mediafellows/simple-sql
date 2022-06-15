default:
	bundle exec rspec

tests: 
	./scripts/integration_tests

stats:
	@scripts/stats lib/simple/sql
	@scripts/stats spec/simple/sql
	@scripts/stats lib/simple/store
	@scripts/stats spec/simple/store
