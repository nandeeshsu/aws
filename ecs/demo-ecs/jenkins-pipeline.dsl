multibranchPipelineJob('demo-ecs') {
    factory {
        workflowBranchProjectFactory {
            scriptPath('ecs/demo-ecs/Jenkinsfile')
        }
    }
    branchSources {
        git {
            id('demo-ecs') // IMPORTANT: use a constant and unique identifier
            remote('https://github.com/nandeeshsu/aws.git')
            credentialsId('72e00ac3-14f0-4df3-9889-43ecd5bc4c5')
        }
    }
    orphanedItemStrategy {
        discardOldItems {
            numToKeep(5)
            daysToKeep(5)
        }
    }

    configure {
        def traits = it / sources / data / 'jenkins.branch.BranchSource' / source / traits
        traits << 'jenkins.plugins.git.traits.BranchDiscoveryTrait' {
            strategyId(3) //detect all branches
        }
    }

    configure {
        def traits = it / sources / data / 'jenkins.branch.BranchSource' / source / traits
        traits << 'jenkins.plugins.git.traits.TagDiscoveryTrait' {
            strategyId(3) //detect all tags
        }
    }

    configure {
        def traits = it / sources / data / 'jenkins.branch.BranchSource' / source / traits
        traits << 'jenkins.scm.impl.trait.WildcardSCMHeadFilterTrait' {
            includes('main develop')  //filter branches/tags
            exclude('someBranch')  //exclude branches/tags
        }
    }
}