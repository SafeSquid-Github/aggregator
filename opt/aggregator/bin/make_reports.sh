#!/bin/bash

/bin/bash /opt/aggregator/bin/make_sarg.sh "$@"
/bin/bash /opt/aggregator/bin/make_calamaris.sh "$@"
/bin/bash /opt/aggregator/bin/make_squint.sh "$@"
/bin/bash /opt/aggregator/bin/make_webalizer.sh "$@"
/bin/bash /opt/aggregator/bin/make_goaccess.sh "$@"
