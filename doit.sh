#!/bin/bash
#

terraform graph | dot -Tpng -o graph.png

#aws s3api create-bucket --bucket rmordasiewiczbucket --region us-west-2
