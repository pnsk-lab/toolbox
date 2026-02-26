#!/usr/bin/env bash
# Sorry for using bash :(

. ./toolbox.conf

export TOOLBOX_SOLR_HOSTNAME
export TOOLBOX_SOLR_PORT
export TOOLBOX_HAMMER_PORT

if [ "x$1" = "x" -o "x$1" = "xhelp" ]; then
	echo "ToolBox - Alternative Scratch Tools"
	echo "Usage: $0 [axe|build|clean|setup] args"
elif [ "x$1" = "xaxe" ]; then
	exec ./axe/axe --directory data "${@:2}"
elif [ "x$1" = "xhammer" -o "x$1" = "x" ]; then
	while true; do
		./hammer/hammer --directory data "${@:2}"
	done
elif [ "x$1" = "xbuild" ]; then
	exec make PCFLAGS=-dDATABASE
elif [ "x$1" = "xclean" ]; then
	exec make clean
elif [ "x$1" = "xsetup" ]; then
	F=false
	if curl -f -X POST -H "Content-Type: application/json" "http://$TOOLBOX_SOLR_HOSTNAME:$TOOLBOX_SOLR_PORT/api/collections" -d '{
		"name": "toolbox",
		"numShards": 1,
		"replicationFactor": 1
	}' >/dev/null 2>&1; then
		:
	else
		echo "Failed to create collection toolbox"
		F=true
	fi
	if curl -f -X POST -H "Content-Type: application/json" "http://$TOOLBOX_SOLR_HOSTNAME:$TOOLBOX_SOLR_PORT/api/collections/toolbox/schema" -d '{
		"add-field": [
			{"name": "project_id", "type": "pint"},
			{"name": "title", "type": "text_general", "multiValued": false},
			{"name": "description", "type": "text_general", "multiValued": false},
			{"name": "instructions", "type": "text_general", "multiValued": false},
			{"name": "author_id", "type": "pint"},
			{"name": "author_name", "type": "string"},
			{"name": "author_search_name", "type": "text_general", "multiValued": false},
			{"name": "timestamp", "type": "string"},
			{"name": "shared_timestamp", "type": "string"}
		]
	}' >/dev/null 2>&1; then
		:
	else
		echo "Failed to create schema for collection toolbox"
		F=true
	fi

	if $F; then
		echo "There were some errors while setting up database"
	fi
fi
