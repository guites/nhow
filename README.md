# nhow - clock in via command line

This simple script is a wrapper around the nhow.com.br \(undocumented\) API.

## Installation

Clone the repo and then copy the env file.

        git clone git@github.com:guites/nhow.git && cd nhow

You should then copy the example.env file and add your own values. They can be found by inspecting the network calls when clocking in using their chrome extension or web page.

        cp example.env .env

You can then check the available commands by running

        ./nhow.sh -h

Tip: add an alias to clock in from wherever.

        echo "alias ,ponto="$(pwd)"/nhow.sh" >> ~/.bashrc && source ~/.bashrc
