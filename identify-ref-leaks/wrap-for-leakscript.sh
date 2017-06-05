#  This is a wrapper script which will run the stap command for detecting
#  leaks. It can be run in interactive as well as non-interactive mode.In
#  interactive mode it will ask few options after running this script. In
#  non-interactive mode, user has to provide the arguments while running this
#  script.

#!/bin/bash

status=1
func_name=""
func_name_unref=""
pid_gluster=""
output_file=""
probe_time=900
module=""
str_length=900
file_size=40
max_no_of_files=100

check_fun_name()
{
        #matching ref function with its counter unref function

        if [[ $status == 0 ]]
        then
                case $func_name in
                        "dict_ref");;
                        "inode_ref");;
                        "fd_ref");;
                        *)
                        echo "Function name can be dict_ref/inode_ref/fd_ref"
                        exit;;
                 esac
        fi

        if [[ $func_no == 1 || $func_name == "dict_ref" ]]
        then
                func_name="dict_ref"
                func_name_unref="dict_unref"
        elif [[ $func_no == 2 || $func_name == "inode_ref"  ]]
        then
                func_name="__inode_ref"
                func_name_unref="__inode_unref"
        elif [[ $func_no == 3 || $func_name == "fd_ref" ]]
        then
                func_name="__fd_ref"
                func_name_unref="__fd_unref"
        else
                echo  "\nWrong choice. Function name can be
                dict_ref/inode_ref/fd_ref"
                exit
        fi
}

fun_name()
{
	echo -e "\nEnter the no. for the function which you wants to probe."
	echo -e  "Press\n1. dict_ref\n2. inode_ref\n3. fd_ref"
	read func_no

        check_fun_name
}

process_id()
{
    echo -e "\nEnter Process Id :"
    read pid_gluster
}

input_output_file()
{
        #creating output file, name based on epoch time

        dir=/var/run/gluster/leak-output
        if [ ! -d $dir ]
        then
               mkdir -p $dir
        fi

        current_time=`date +%s`
	output_file="trace-"$current_time
	echo -e "\noutput file : $output_file at "$dir

        #input file
        input_file="./ref-leak-identify.stp"

}

check_probe_time()
{
        temp_time=$1

        if [[ -z $temp_time ]]
        then
                probe_time=900
        else
                probe_time=$(( temp_time*60 ))
        fi
}

time_int()
{
	echo -e "\nEnter probing time interval in minutes : "
	echo -e "( Default is 15 minutes )"
	read probe_time
        check_probe_time probe_time
}



select_module()
{
        #Checking installation is from source or by rpm and assigning
        #xlators accordingly.

        gluster_version=`gluster --version | cut -d ' ' -f 2 | grep dev`

        rpm_res1=`rpm -q glusterfs`
        rpm_res2=`rpm -q glusterfs-server`

        if [[ "$rpm_res1" == "glusterfs"* ]]
	then
                temp1=1
                client_module=`rpm -ql glusterfs | grep .so`
	        module_temp=$client_module
        fi

        if [[ "$rpm_res2" == "glusterfs-server"* ]]
        then
                temp2=1
                server_module=`rpm -ql glusterfs-server | grep .so`
                module_temp=$server_module
	fi

        if [ $temp1 -eq 1 -a $temp2 -eq 1 ]
        then
                module_temp=$client_module" "$server_module
        else
                module_temp=`find /usr/local/lib/glusterfs/$gluster_version/
                -name "*.so"`
        fi

        module=( $module_temp )
}

prep_and_exec_command()
{
        #preparing command

	com1="stap"
	com2=""
	com3=" -d "

        for val in "${module[@]}"
        do
                com2=$com2$com3$val
	done

	com4=" -g --suppress-time-limits -DMAXSTRINGLEN=$str_length"
        com5=" -S $file_size,$max_no_of_files -o "
	com6=$dir"/"$output_file
	com7=" -v "$input_file" -x "$pid_gluster
	com8=" "$func_name" "$func_name_unref" "$probe_time
	full_com=$com1$com2$com4$com5$com6$com7$com8
	echo -e "\n$full_com"

        #executing command
	eval "$full_com"
}

call_functions()
{
        #bsaed on interactive/non-interactive mode, calling functions

	if [ $status -eq 1 ]
	then
	    fun_name
	    process_id
            time_int
        fi

	input_output_file
	select_module
	prep_and_exec_command
}


usage()
{
         echo "usage: $0 -f function_name -p pid [-t time-interval]"
}

#To run non-interactively
while [ $# -gt 0 ]
do
        status=0
        case "$1" in
                -f)
                        shift
                        func_name="$1"
                        check_fun_name
                        ;;
                -p)
                        shift
                        pid_gluster="$1"
                        ;;
                -t)
                        shift
                        check_probe_time $1
                        ;;
                -h)
                        usage
                        exit 1
                        ;;
                -* | *)
                        usage
                        exit 1
                        ;;
        esac
        shift
done

if [ $status == 0 ]
then
        if [[ -z $func_name || -z $pid_gluster ]]
        then
                usage
                exit
        fi
fi

call_functions

