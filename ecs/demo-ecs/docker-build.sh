#!/bin/bash

checkTagName() {
  case $1 in
  "hot")
    echo "hot"
    FROM_TAG=hotfix-$BRANCH_RELEASE
    TO_TAG=$FULL_BRANCH
    ;;

  "dev")
    echo "dev"
    FROM_TAG=dev
    TO_TAG=dev
    ;;

  "cit")
    echo "cit"
    FROM_TAG=release-$BRANCH_RELEASE
    TO_TAG=$FULL_BRANCH
    ;;

  "sit")
   echo "sit"
    if [[ "$ALL_FOLDERS" == *"cit"* ]]; then
      FROM_TAG=cit-$BRANCH_RELEASE
      TO_TAG=$FULL_BRANCH
    else
      FROM_TAG=release-$BRANCH_RELEASE
      TO_TAG=$FULL_BRANCH
    fi
    ;;

  "uat")
    echo "uat"
    FROM_TAG=sit-$BRANCH_RELEASE
    TO_TAG=$FULL_BRANCH
    ;;
  "pre")
    echo "pre"
    if [[ "$ALL_FOLDERS" == *"uat"* ]]; then
      echo "Pulling UAT-$BRANCH_RELEASE image to tag and create PRE-$BRANCH_RELEASE"
      FROM_TAG=uat-$BRANCH_RELEASE
      TO_TAG=$FULL_BRANCH
    else
      if [[ "$ALL_FOLDERS" == *"sit"* ]]; then
        echo "No UAT folder detected, using the SIT-$BRANCH_RELEASE image to tag and create PRE-$BRANCH_RELEASE"
        FROM_TAG=sit-$BRANCH_RELEASE
        TO_TAG=$FULL_BRANCH
      else
        echo "No UAT or SIT folder detected, failing the build. DEV, SIT and PRD folders are required for all projects"
        exit 1
      fi
    fi
    ;;
  "prd")
    echo "prd"
    if [[ "$ALL_FOLDERS" == *"pre"* ]]; then
      FROM_TAG=pre-$BRANCH_RELEASE
      TO_TAG=$FULL_BRANCH
    else
      if [[ "$ALL_FOLDERS" == *"uat"* ]]; then
        echo "No PRE folder detected, using the uat-$BRANCH_RELEASE image to tag and create prd-$BRANCH_RELEASE"
        FROM_TAG=uat-$BRANCH_RELEASE
        TO_TAG=$FULL_BRANCH
      else
        if [[ "$ALL_FOLDERS" == *"sit"* ]]; then
          echo "No UAT folder detected, using the sit-$BRANCH_RELEASE image to tag and create prd-$BRANCH_RELEASE"
          FROM_TAG=sit-$BRANCH_RELEASE
          TO_TAG=$FULL_BRANCH
        else
          echo "No PRE, UAT or SIT folder detected, failing the build. DEV, SIT and PRD folders are required for all projects"
          exit 1
        fi
      fi
    fi
    ;;
  "feature")
    echo "feature"
    FROM_TAG=dev
    TO_TAG=dev
    ;;
  "release")
    echo "release"
    FROM_TAG=dev
    TO_TAG=$FULL_BRANCH
    ;;
  "hotfix")
    echo "hotfix"
    FROM_TAG=dev
    TO_TAG=$FULL_BRANCH
    ;;
  "develop")
    echo "develop"
    FROM_TAG=dev
    TO_TAG=dev
    ;;
  *)
    echo "Unknown tag name $1, aborting the build"
    exit
    ;;
  esac
}

export BRANCH_NAME=$BRANCH_NAME
export FULL_BRANCH=$BRANCH_NAME
export SHORT_BRANCH=$(echo $BRANCH_NAME | cut -d'-' -f1)
checkTagName $SHORT_BRANCH
echo "Branch prefix="$SHORT_BRANCH
export BRANCH_RELEASE=$(echo $BRANCH_NAME | cut -d'-' -f2)
echo "Branch suffix="$BRANCH_RELEASE
if [[ "$SHORT_BRANCH" == *"prd"* ]]; then
    echo "Builing the prd container"
    echo "docker pull image $FROM_TAG to create container $TO_TAG"
else
    if [[ "$SHORT_BRANCH" == *"hot" ]]; then
        echo "Building the hot container"
        echo "docker pull image $FROM_TAG to create container $TO_TAG"
else
    if [[ "$SHORT_BRANCH" == *"dev"* ]]; then
      echo "Building the dev container - build new image"
      echo "TO_TAG $TO_TAG"
    else
      if [[ "$SHORT_BRANCH" == *"release"* ]]; then
        echo "Building the release container- build new image"
        echo "TO_TAG $TO_TAG"
      else
        if [[ "$SHORT_BRANCH" == *"hotfix"* ]]; then
            echo "Building the hotfix container- build new image"
            echo "TO_TAG $TO_TAG"
        else
         echo "Building image not caught by tags"
     fi
   fi
 fi
  fi
fi