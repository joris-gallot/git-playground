<template>
  <div class="flex justify-between gap-12 md:items-center -md:flex-col">
    <Highlight
      v-if="iOnHisOwnProfile && !skill.comment && !isEditingComment"
      v-slot="{ isOpen }"
      :interactionType="FIRST_INTERACTION_TYPES.SKILL_COMMENT_HIGHLIGHT"
      img="/img/highlight-skill-comment.png"
      :title="$t('skill.comment.highlight.title')"
      :description="$t('skill.comment.highlight.description')"
      :button="$t('skill.comment.highlight.close')"
    >
      <div class="relative inline-flex transition-all" :class="{ 'ring-2 ring-primary-950 ring-offset-2': isOpen }">
        <HighlightTrigger class="absolute right-[-20px] top-0 -translate-x-1/2 -translate-y-1/2" />
        <Btn
          iconLeft="plus-rounded"
          variant="secondary"
          @click="
            comment = skill.comment || '';
            trackAddCommentClick();
          "
        >
          {{ $t('skill.comment.add') }}
        </Btn>
      </div>
    </Highlight>
  </div>
</template>