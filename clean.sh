hosts=$(awk '{print $2;}' < hosts)
for host in $hosts
do
    docker rm -f $host
done

docker volume remove kafka-shared
