# bash completion for sspinner
# sourced by install.sh from ~/.bashrc - no bash-completion package required

_sspinner() {
    local cur cword
    cur="${COMP_WORDS[COMP_CWORD]}"
    cword=$COMP_CWORD

    # 'down' is a deprecated alias for 'stop' - still completes since it
    # still works, but 'stop' is the advertised name
    local commands="register edit list status run restart stop down logs exec doctor infra"

    if [ "$cword" -eq 1 ]; then
        COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
        return 0
    fi

    local sub="${COMP_WORDS[1]}"
    case "$sub" in
        register|edit|run|stop|down|status|doctor)
            if [ "$cword" -eq 2 ]; then
                local names
                names=$(sspinner _names 2>/dev/null)
                COMPREPLY=( $(compgen -W "$names" -- "$cur") )
            fi
            ;;
        restart|logs)
            if [ "$cword" -eq 2 ]; then
                local names
                names=$(sspinner _names 2>/dev/null)
                COMPREPLY=( $(compgen -W "$names" -- "$cur") )
            elif [ "$cword" -ge 3 ]; then
                local services
                services=$(sspinner _services "${COMP_WORDS[2]}" 2>/dev/null)
                COMPREPLY=( $(compgen -W "$services" -- "$cur") )
            fi
            ;;
        exec)
            # exec <project> <service> [-c/--container CONTAINER] <command>...
            # - only <project>, <service> and the container flag/value
            # complete; <command> is arbitrary and can't be.
            if [ "$cword" -eq 2 ]; then
                local names
                names=$(sspinner _names 2>/dev/null)
                COMPREPLY=( $(compgen -W "$names" -- "$cur") )
            elif [ "$cword" -eq 3 ]; then
                local services
                services=$(sspinner _docker_services "${COMP_WORDS[2]}" 2>/dev/null)
                COMPREPLY=( $(compgen -W "$services" -- "$cur") )
            elif [ "$cword" -eq 4 ]; then
                COMPREPLY=( $(compgen -W "-c --container" -- "$cur") )
            elif [ "$cword" -eq 5 ] && { [ "${COMP_WORDS[4]}" = "-c" ] || [ "${COMP_WORDS[4]}" = "--container" ]; }; then
                local containers
                containers=$(sspinner _containers "${COMP_WORDS[2]}" "${COMP_WORDS[3]}" 2>/dev/null)
                COMPREPLY=( $(compgen -W "$containers" -- "$cur") )
            fi
            ;;
        infra)
            if [ "$cword" -eq 2 ]; then
                COMPREPLY=( $(compgen -W "up down" -- "$cur") )
            fi
            ;;
    esac
    return 0
}

complete -F _sspinner sspinner
