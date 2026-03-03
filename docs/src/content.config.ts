import { defineCollection } from 'astro:content';
import { docsSchema } from '@astrojs/starlight/schema';
import { docsLoader } from '@astrojs/starlight/loaders';

const docs = defineCollection({
	loader: docsLoader(),
	schema: docsSchema(),
});

export const collections = { docs };
