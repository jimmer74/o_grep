package main

//core libraries
import "core:fmt"
import "core:os"
import "core:strings"
import "core:bytes"

main :: proc() {
	
	cmd_args := os.args[1:] //get an array of strings of args (excluded arg 0 which is exe path)
	num_args := len(cmd_args)

	fd_in, fd_out: os.Handle // input and output file decripters of Handle type
	fd_out = os.stdout // output Handle is always stdout for this app
	in_buf: [] byte // input buffer to hold text read from stdin or file
	out_buf: [dynamic] byte // output buffer to fill with matches and output to stdout 


	defer { //delete at end of scope
		delete(in_buf)
		delete(out_buf)
	}

	read_ok:bool = false
	fname,search: string

	//error guard. Exit if no args supplied
	if num_args > 0 {
		search, fname = cmd_line_parser(cmd_args)
	} else {
		print_usage()
		return
	}


	// use stdin as Handle unless filename is provided
	if fname != "" {
		err:os.Errno
		fd_in,err = os.open(fname,os.O_RDONLY) 
		if err != 0 {
			print_usage()
			return //bail out
		} 
	} else {
		fd_in = os.stdin		
	}

	//fill input buffer from ether stdin or file
	in_buf,read_ok = os.read_entire_file(fd_in,context.allocator)
	if !read_ok {
		fmt.println("Read Error, aborting")
		return //bail out
	}
	
	//fill output buffer with matched lines with highlighted searches 
	out_buf = grep(in_buf,search)

	//write output buffer to stdout
	for char in out_buf{
		os.write_byte(fd_out, cast(byte)char)
	}
	
}

/*
 grep:

 	takes a data buffer and a search string as input.

 	outputs a buffer containing any lines with the search 
	string ( with added ANSI colour highlighting  )

*/

grep :: proc (data: []byte, search: string) -> (out_buf: [dynamic]byte){

	
	match: bool = false
	in_line := make([dynamic]byte, 0, 1000)
	ret_line := make([dynamic]byte, 0, 1000)	
	defer {
		delete(in_line)
		delete(ret_line)
	}

	for dat in data {
		
		//fill buffer with current line
		if dat != '\n'{
			append(&in_line,dat)
		}
		else
		{
			//line finished, process it for a match
			ret_line, match = line_grep(in_line,search)
			//if a match, add line (including colour highlighting) to the output buffer
			if match {
				for letter in ret_line { 
					append(&out_buf, letter)
				}
				append(&out_buf, '\n') // add line feed back in to buffer.
				match = false
			}
			//clear out old line and ret buffers
			delete_dynamic_array(in_line) 
			delete_dynamic_array(ret_line)
			//re-create them for next go around
			in_line = make([dynamic]byte, 0, 1000) 
			ret_line = make([dynamic]byte, 0, 1000)
		}
		
	}

	return
}
/*
 line_grep:
	takes a dynamic buffer containg a line and search query as a string.

	returns a dynamic buffer containing the line with any matches highlighted 
			and a boolean to indicate a successful match

	TODO: Has a bug where if a letter repeats in a search term, the whole \
	TODO: rest of the line is highlighted

*/
@private
line_grep :: proc (data: [dynamic]byte, search: string) -> (out_buf: [dynamic]byte, ret_match: bool){

	sch_idx: int = 0
	match := false
	ret_match = false
	
	for dat,dat_idx in data {
		if data[dat_idx] == search[0] { //we matched 1st char of search
			for letter, idx in search
			{
				if cast(byte)letter == data[dat_idx + idx] { //lookahead the length of the search string to see if an exact match
					match = true //keep matching chars
				}
				else {
					match = false //doesn't match full search string
					break // want to exit look ahead
				}
			}
		} 
		
		//colour highlighting logic (uses ANSI terminal codes) for fancy output
		if(match) {
			ret_match = true
			if (len(search) == 1) //special case for single char search
			{
				append(&out_buf, ANSI_PUR) //start colour
				append(&out_buf, data[dat_idx]) 
				append(&out_buf, ANSI_RST) //end colour
				match = false
			} 
			else if sch_idx < len(search) - 1 // haven't got to last char of match yet
			{
				if sch_idx == 0 { 
					append(&out_buf, ANSI_PUR) 
				}
				append(&out_buf, data[dat_idx])
				sch_idx += 1
			} 
			else 
			{
				append(&out_buf, data[dat_idx]) //last char of match
				append(&out_buf, ANSI_RST) //turn off colour
				match = false // back to normal processing
				sch_idx = 0
			}
		} 
		else { //process non-coloured text
			append(&out_buf, data[dat_idx])
		}

	} //end of for loop for processing input line buffer
	return
}


/*
cmd_line_parser:
	takes an array of strings containing options
Valid options:
	-e "search string"
	-f "filename"
Returns:
	a string with search query: search
	a string with filename: fname

*/
cmd_line_parser :: proc(cmd_args: []string) -> (search: string, fname: string){
	
	search_arg,file_arg: bool = false, false
	s := make([]byte,100)
	//defer delete(s)
	f : string

	for arg in cmd_args {
		switch(arg)
		{
			case "-e": search_arg = true //set true for next swing through args
			case "-f": file_arg = true
			case: {
				if search_arg { //last arg was -e, so this arg is "search string"
					search_arg = false
					search = arg
					//fmt.println("search term:",search)
				} else if file_arg { //last arg was -f, so this arg is "filename"
					file_arg = false
					f    = arg
				}
			}
		}
	}

	return search, f

} 

/* err_to_string :: proc(err: os.Errno) -> (string){
	return cast(string)os._darwin_string_error(cast(i32)err)
} */

print_usage :: proc() {
	fmt.println("Usage:")
	fmt.println("\to_grep -e \"search term\" -f filename.txt")
	fmt.println("or:")
	fmt.println("\to_grep -e \"search term\" < filename.txt")
}

