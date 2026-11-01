import {notFound} from 'next/navigation';import {resources} from '@/lib/resources';import ResourcePage from '@/components/ResourcePage';
export function generateStaticParams(){return Object.keys(resources).map(resource=>({resource}));}
export default async function Page({params}:{params:Promise<{resource:string}>}){const{resource}=await params;if(!resources[resource])notFound();return <ResourcePage resource={resource}/>;}
