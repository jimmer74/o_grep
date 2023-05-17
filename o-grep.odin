package main

//core libraries
import "core:fmt"
import "core:os"
import "core:strings"
import "core:bytes"

main :: proc() {
	
	cmd_args := os.args[1:]
	num_args := len(cmd_args)

	fd_in, fd_out: os.Handle
	fd_out = os.stdout
	data: [] byte 
	out_buf: [dynamic] byte
	defer {
		delete(data)
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

	data,read_ok = os.read_entire_file(fd_in,context.allocator)
	if !read_ok {
		fmt.println("Read Error, aborting")
		return //bail out
	}
	
	
	
	out_buf = grep(data,search)

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


	line_buf := make( [dynamic]byte, 0 , 1000)
	ret_line := make([dynamic]byte, 0, 1000)	
	defer {
		delete(line_buf)
		delete(ret_line)
	}
	match: bool = false
	line_idx := 0
	for dat in data {
		
		if dat != '\n'{
			append(&line_buf,dat)
		}
		else
		{

			ret_line, match = line_grep(line_buf,search)
			if match {
				for letter in ret_line { 
					append(&out_buf, letter)
				}
				append(&out_buf, '\n') // add line feed back in to buffer.
				match = false
			}
			 
			delete_dynamic_array(line_buf) //clear out old line and ret buffers
			delete_dynamic_array(ret_line)
			line_buf = make( [dynamic]byte, 0 , 1000) //re-create them for next go around
			ret_line = make([dynamic]byte, 0, 1000)
		}

		
	}

	return
}

//@private
line_grep :: proc (data: [dynamic]byte, search: string) -> (out_buf: [dynamic]byte, ret_match: bool){

	sch_idx: int = 0
	out_buf_idx: int = 0
	match := false
	ret_match = false
	
	for dat,dat_idx in data {
		if data[dat_idx] == search[0] { //match 1st char
			for letter, idx in search
			{
				if cast(byte)letter == data[dat_idx + idx] { //lookahead the length of the search string to see if an exact match
					match = true //keep matching chars
				}
				else {
					match = false //doesn't match full search string, want to exit look ahead
				}

				if(!match) {break} // no point continuing to check letters: bail out of for loop since match is a bust
			}
		} 
		
		//colour highlighting logic (uses ANSI terminal codes) for fancy output
		if(match) {
			ret_match = true
			if (len(search) == 1) //special case for single char search
			{
				append(&out_buf, ANSI_PUR)
				append(&out_buf, data[dat_idx])
				append(&out_buf, ANSI_RST)
				out_buf_idx += 3
				match = false
			} 
			else if sch_idx < len(search) - 1 // haven't got to last char of match yet
			{
				if sch_idx == 0 { 
					append(&out_buf, ANSI_PUR) 
					out_buf_idx += 1
				}
				append(&out_buf, data[dat_idx])
				out_buf_idx += 1
				sch_idx += 1
			} else {
				append(&out_buf, data[dat_idx]) //last char of match
				append(&out_buf, ANSI_RST) //turn off colour
				out_buf_idx += 2
				sch_idx = 0
				match = false // back to normal processing
			}
		} else { 
			append(&out_buf, data[dat_idx])
			out_buf_idx += 1
		}

	}
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

