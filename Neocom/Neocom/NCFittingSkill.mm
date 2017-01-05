//
//  NCFittingSkill.m
//  Neocom
//
//  Created by Artem Shimanski on 04.01.17.
//  Copyright © 2017 Artem Shimanski. All rights reserved.
//

#import "NCFittingSkill.h"
#import "NCFittingProtected.h"

@implementation NCFittingSkill

- (NSInteger) level {
	auto skill = std::dynamic_pointer_cast<dgmpp::Skill>(self.item);
	return skill->getSkillLevel();
}

- (void) setLevel:(NSInteger)level {
	auto skill = std::dynamic_pointer_cast<dgmpp::Skill>(self.item);
	return skill->setSkillLevel(static_cast<int>(level));
}

@end
