set -eux

#### Install cosign

go install github.com/sigstore/cosign/cmd/cosign@latest


#### Pull nginx image 
#### !!!CHANGE THE DOCKER USER TO YOUR OWN!!!
DOCKER_USER=mcelep

docker pull nginx:latest

#### Create digest based tag
IMAGE_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' nginx:latest)
DIGEST=$(echo $IMAGE_DIGEST | cut -d ":" -f2)
SHORT_DIGEST=${DIGEST:0:12}
docker tag nginx:latest "${DOCKER_USER}/nginx:${SHORT_DIGEST}"
docker push "${DOCKER_USER}/nginx:${SHORT_DIGEST}"
NEW_IMAGE_DIGEST=$(docker inspect --format='{{index .RepoDigests 1}}' ${DOCKER_USER}/nginx:${SHORT_DIGEST})

#### Cosign via google/github/etc.

COSIGN_EXPERIMENTAL=1 cosign sign -y "$NEW_IMAGE_DIGEST"


#### Verify signature 

COSIGN_EXPERIMENTAL=1 cosign verify "$NEW_IMAGE_DIGEST"
