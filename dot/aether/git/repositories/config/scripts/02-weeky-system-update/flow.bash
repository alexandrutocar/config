git clone $BARE_REPO_PATH $REPO_PATH
cd $REPO_PATH
# ---

PACKAGES_LAST_COMMIT_SHA1=$(
    gh api graphql -f query='
        query {
          repository(owner: "nixos", name: "nixpkgs") {
            ref(qualifiedName: "refs/heads/nixos-unstable-small") {
              target {
                ... on Commit {
                  history(until: "2026-04-24T22:00:00Z", first: 1) {
                    edges {
                      node {
                        oid
                      }
                    }
                  }
                }
              }
            }
          }
        }
        ' | 
        jq -r '.data.repository.ref.target.history.edges[0].node.oid' 
)

PACKAGES_LAST_COMMIT_DATE=$(
    gh api graphql -f query='
        query {
          repository(owner: "nixos", name: "nixpkgs") {
            ref(qualifiedName: "refs/heads/nixos-unstable-small") {
              target {
                ... on Commit {
                  history(until: "2026-04-24T22:00:00Z", first: 1) {
                    edges {
                      node {
                        committedDate
                      }
                    }
                  }
                }
              }
            }
          }
        }
        ' | 
        jq -r '.data.repository.ref.target.history.edges[0].node.committedDate' 
)

# ---
git add .
git commit -m "[Flow]: Weekly System Update"
git push origin main