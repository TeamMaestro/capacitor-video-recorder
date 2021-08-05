import { registerPlugin } from '@capacitor/core';

import type { VideoRecorderPlugin } from './definitions';

const VideoRecorder = registerPlugin<VideoRecorderPlugin>(
    'VideoRecorder',
    {
        web: () => import('./web').then(m => new m.VideoRecorderWeb()),
    },
);

export * from './definitions';
export { VideoRecorder };
