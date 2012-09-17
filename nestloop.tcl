#!/bin/sh
# nestloop.tcl \
# exec tclsh "$0" ${1+"$@"}


proc vtovp {v hex digits} {
	if {[string match -nocase $hex "0x"]==1} {
		if {$digits > 0} {
			set vp [format "%0${digits}X" $v] 
		} else {
			set vp [format "%X" $v] 
		}
	} else {
		if {$digits > 0} {
			set vp [format "%0${digits}d" $v] 
		} else {
			set vp [format "%d" $v] 
		}
	}
	return $vp							
}
 
proc parse_nest_loop {input} {
    # parse_nest_loop parses an input that contains <> notation to indicate
    # nested loops. <a-b> means loop from a-b, <<a-b>> means inner-loop
    #
    # the number of < is the nested level
    #
    # multiple levels of loops, and multiple loops of the same levels
    # can exist together. Same level of loops can have different number of
    # iteration times. The loop ends when the longest loop in the same
    # level ends. The shorter loop will continue from beginning.
    #
    #
    # example:
    # parse_nest_loop "1<0-5>.<<1-5>>" returns:
    # 10.1, 10.2, ..., 10.5,
    # 11.1, 11.2, ..., 11.5,
    # ...
    # 15.1, 15.2, ..., 15.5
    #
    # parse_nest_loop "<0-5><0-3>" returns:
    # 00 11 22 33 40 51
    #
 

    set level 0
    set loops [regexp -inline -all {<+(0[xX])?[0-9a-fA-F]+-(0[xX])?[0-9a-fA-F]+>+} $input]
    set count 0
    # generating looparry.
    # looparray is the control array for the loops. It is generated by
    # parsing the nest loop sytax string
    # The index of looparray must be sequencial from 1 to N
    # N is the innest loop while 1 is the out most loop
    foreach loop $loops {
        #puts "loop = $loop"
        if {[string length $loop]==0 || [string match -nocase "0x" $loop]==1} {
            continue
        }
        if {[regexp {^(<+)(0[xX])?([0-9a-fA-F]+)-(0[xX])?([0-9a-fA-F]+)(>+)$} $loop - b1 hx start - stop b2] ==0} {
            error "$input cannot be parsed at: $loop"
        }
        if {[string length $b1]!=[string length $b2]} {
            error "$input cannot be parsed at: $loop, '<' '>' not match"
        }
        if {$start == $stop} {
            error "$input infinit loop"
        }
        if {$start < $stop} {
            set increment 1
        } else {
            set increment -1
        }
		set digits 0
		if {[string length $start] == [string length $stop]} {
			set digits [string length $start]
		}
        set level [string length $b1]
        set varname "<LOOP $level $count>"
        lappend replacelist $varname
        incr count
        if {![info exist looparray($level)]} {
            set looparray($level) [list [list $varname $start $stop $increment $hx $digits]]
        } else {
            lappend looparray($level) [list $varname $start $stop $increment $hx $digits]
        }
        set input [regsub $loop $input $varname]
    }
    #parray looparray
    
    set maxlevel [llength [array name looparray]]
    set rindex [lsort -integer -decreasing [array name looparray]]
    set index [lsort -integer -increasing [array name looparray]]
    #
    # v is the iteration value that changes on each step
	# vp is the presentation of the value
	# vp is calculated by vtovp
    # max and min are the boundary
    #
    foreach i $index {
        set max_iteration_index($i) 0
        for {set j 0} {$j<[llength $looparray($i)]} {incr j} {
			set vp($i,$j) [lindex [lindex $looparray($i) $j] 1]
			set hex($i,$j) [lindex [lindex $looparray($i) $j] 4]
			# use decimal for calculation
            set step($i,$j) [expr $hex($i,$j)[lindex [lindex $looparray($i) $j] 3] ]
            set max($i,$j) [expr $hex($i,$j)[lindex [lindex $looparray($i) $j] 2] ]	
            set min($i,$j) [expr $hex($i,$j)[lindex [lindex $looparray($i) $j] 1] ]
			set v($i,$j) $min($i,$j)
			set width($i,$j) [lindex [lindex $looparray($i) $j] 5]
            set iterations [expr abs( ($max($i,$j)-$min($i,$j))/$step($i,$j) ) ]
            set max_iterations [expr abs( ($max($i,$max_iteration_index($i))-$min($i,$max_iteration_index($i)))/$step($i,$max_iteration_index($i)) ) ]
            if {$iterations > $max_iterations} {
                set max_iteration_index($i) $j
            }
        }
    }
	
    #parray max_iteration_index
    #parray max
    #parray min
    #parray step
    #parray hex
    #parray width
	
    set out 0
    set MAXLOOP 100000
    for {set fake 0} {$fake < $MAXLOOP} {incr fake} {

        # the fake array is a poor man's solution to avoid infinite loop.
        
        # Check if we should break the loop by
        # re-calculate the index value
        # Check from the innest loop to outer.
        foreach i $rindex {
            for {set j 0} {$j < [llength $looparray($i)]} {incr j} {
                if {[expr $v($i,$j) - $max($i,$j)]>0} { # if any level exceed the max value
                    if {$j==$max_iteration_index($i)} {
                        if {$i==[lindex $rindex end]} {
                            # If it is the out most loop, break
                            set out 1
                        } else {
                            # otherwise, set current level to the min
                            # increase a level up by 1
                            for {set k 0} {$k < [llength $looparray($i)]} {incr k} {
								set tmp_index "$i,$k"
								set v($tmp_index) $min($tmp_index)
								set vp($tmp_index) [vtovp $v($tmp_index) $hex($tmp_index) $width($tmp_index)]			
                            }
                            for {set k 0} {$k < [llength $looparray([expr $i-1])]} {incr k} {
								set tmp_index "[expr $i-1],$k"
                                set sum [expr $v($tmp_index) + $step($tmp_index)]
								set v($tmp_index) $sum
                                set vp($tmp_index) [vtovp $v($tmp_index) $hex($tmp_index) $width($tmp_index)]
                            }
                        }
                    } else {
                        set v($i,$j) $min($i,$j)
						set vp($i,$j) [vtovp $v($i,$j) $hex($i,$j) $width($i,$j)]
                    }
                }
                if {$out} break
            }
            if {$out} break
        }
        if {$out} {
            #puts "normal break"
            break
        }
        set map_list ""
        foreach i $index {
            for {set j 0} {$j < [llength $looparray($i)]} {incr j} {
                lappend map_list [lindex [lindex $looparray($i) $j] 0] $vp($i,$j)
            }
        }
        lappend result [string map $map_list $input]
        # since we have the check and increment at the beginning of the loop,
        # we just need increase the innest loop here.
        for {set j 0} {$j < [llength $looparray($i)]} {incr j} {
			set tmp_index "$maxlevel,$j"
            set sum [expr $v($tmp_index) + $step($tmp_index)]
            set v($tmp_index) $sum
            set vp($tmp_index) [vtovp $v($tmp_index) $hex($tmp_index) $width($tmp_index)]
            
            #incr v($maxlevel,$j) $step($maxlevel,$j)
        }
    }
    if {$fake==$MAXLOOP} {
        puts "Loops more than $MAXLOOP times, sytax error in the loop string? "
    }
    return $result
}


# a simple test:
proc unit_test {} {
	set output [parse_nest_loop {"zone 2/2" <20-28>.<<<0-99>>>.<<221-223>>/24 <20-28>.<<<0-99>>>.1 <<<0x00-ff>>>:<<<0x00-63>>> <20-28><<<00-99>>>}]
	set test_result "pass"
	
	puts -nonewline "total length test .......................... "
	if {[llength $output] != 6912 } {
		puts "failed"
		set test_result "fail"
	} else {
		puts "passed"
	}
	
	set test_seq {	
		0		{"zone 2/2" 20.0.221/24 20.0.1 00:00 2000}
		1		{"zone 2/2" 20.1.221/24 20.1.1 01:01 2001}
		9		{"zone 2/2" 20.9.221/24 20.9.1 09:09 2009}
		10		{"zone 2/2" 20.10.221/24 20.10.1 0A:0A 2010}
		99		{"zone 2/2" 20.99.221/24 20.99.1 63:63 2099}
		100		{"zone 2/2" 20.0.221/24 20.0.1 64:00 2000}
		0xfe	{"zone 2/2" 20.54.221/24 20.54.1 FE:36 2054}
		0xff	{"zone 2/2" 20.55.221/24 20.55.1 FF:37 2055}
		0x100	{"zone 2/2" 20.0.222/24 20.0.1 00:00 2000}
		1000	{"zone 2/2" 21.32.221/24 21.32.1 E8:20 2132}
		2000	{"zone 2/2" 22.8.222/24 22.8.1 D0:08 2208}
		3000	{"zone 2/2" 23.84.223/24 23.84.1 B8:54 2384}
		4000	{"zone 2/2" 25.60.221/24 25.60.1 A0:3C 2560}
		5000	{"zone 2/2" 26.36.222/24 26.36.1 88:24 2636}
		6000	{"zone 2/2" 27.12.223/24 27.12.1 70:0C 2712}
		6911	{"zone 2/2" 28.55.223/24 28.55.1 FF:37 2855}
	}

	foreach {i j} $test_seq {
		puts -nonewline "Index $i .................................. "
		if {[lindex $output $i] != $j } {
			puts "failed"
			set test_result "fail"
		} else {
			puts "passed"
		}
	}
	
	return $test_result
}





