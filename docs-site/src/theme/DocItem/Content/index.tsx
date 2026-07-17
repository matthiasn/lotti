import React, {type ReactNode} from 'react';
import OriginalDocItemContent from '@theme-original/DocItem/Content';
import type {Props} from '@theme/DocItem/Content';

import TranslationNotice from '@site/src/components/TranslationNotice';

export default function DocItemContent({children}: Props): ReactNode {
  return (
    <>
      <TranslationNotice />
      <OriginalDocItemContent>{children}</OriginalDocItemContent>
    </>
  );
}
