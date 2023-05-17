
.DEFAULT_GOAL := debug

debug:
	@odin build . -debug -out:o_grep

run:
	@odin run . -debug -out:o_grep

release:
	@odin build . -out:o_grep

check:
	@odin check .

clean: 
	@rm ./o_grep
